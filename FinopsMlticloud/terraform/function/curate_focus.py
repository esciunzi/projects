"""Curate the newest AWS FOCUS CSV export into one OCI object per usage date."""

import boto3
import csv
import datetime as dt
import gzip
import http.client
import io
import os
import tempfile
from pathlib import PurePosixPath
from urllib.parse import quote, urlsplit, urlunsplit


s3 = boto3.client("s3")


def _target_date():
    lag_days = int(os.environ.get("TARGET_LAG_DAYS", "1"))
    return (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=lag_days)).date().isoformat()


def _latest_csv_object(bucket, prefix):
    paginator = s3.get_paginator("list_objects_v2")
    candidates = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        candidates.extend(
            item for item in page.get("Contents", [])
            if item["Key"].lower().endswith((".csv", ".csv.gz"))
        )
    if not candidates:
        raise RuntimeError(f"No CSV or CSV.GZ objects found under s3://{bucket}/{prefix}")
    return max(candidates, key=lambda item: item["LastModified"])["Key"]


def _read_csv(bucket, key):
    body = s3.get_object(Bucket=bucket, Key=key)["Body"]
    if key.lower().endswith(".gz"):
        return io.TextIOWrapper(gzip.GzipFile(fileobj=body), encoding="utf-8-sig", newline="")
    return io.TextIOWrapper(body, encoding="utf-8-sig", newline="")


def _row_usage_date(row):
    for column in ("ChargePeriodStart", "ChargePeriodStartTimestamp"):
        value = row.get(column)
        if value:
            return value[:10]
    raise ValueError("The FOCUS CSV has no ChargePeriodStart column")


def _par_object_url(par_url, object_name):
    parts = urlsplit(par_url)
    path = f"{parts.path.rstrip('/')}/{quote(object_name, safe='/')}"
    return urlunsplit((parts.scheme, parts.netloc, path, parts.query, ""))


def _put_file(url, filename):
    parts = urlsplit(url)
    path = urlunsplit(("", "", parts.path, parts.query, ""))
    connection = http.client.HTTPSConnection(parts.netloc, timeout=120)
    connection.putrequest("PUT", path)
    connection.putheader("Content-Type", "application/gzip")
    connection.putheader("Content-Length", str(os.path.getsize(filename)))
    connection.endheaders()
    with open(filename, "rb") as payload:
        while chunk := payload.read(1024 * 1024):
            connection.send(chunk)
    response = connection.getresponse()
    response.read()
    if response.status not in (200, 201):
        raise RuntimeError(f"OCI Object Storage returned HTTP {response.status}: {response.reason}")


def handler(event, context):
    bucket = os.environ["AWS_SOURCE_BUCKET"]
    prefix = os.environ.get("AWS_SOURCE_PREFIX", "")
    target_date = _target_date()
    source_key = _latest_csv_object(bucket, prefix)

    with _read_csv(bucket, source_key) as source:
        reader = csv.DictReader(source)
        if not reader.fieldnames:
            raise RuntimeError(f"Source object s3://{bucket}/{source_key} has no CSV header")

        with tempfile.NamedTemporaryFile(suffix=".csv.gz", delete=False) as temporary:
            temporary_name = temporary.name
        try:
            count = 0
            with gzip.open(temporary_name, "wt", encoding="utf-8", newline="") as output:
                writer = csv.DictWriter(output, fieldnames=reader.fieldnames, extrasaction="ignore")
                writer.writeheader()
                for row in reader:
                    if _row_usage_date(row) == target_date:
                        writer.writerow(row)
                        count += 1

            if count == 0:
                raise RuntimeError(f"No rows for usage date {target_date} in s3://{bucket}/{source_key}")

            filename = f"aws_focus_daily__usage_date={target_date}.csv.gz"
            object_name = str(PurePosixPath(os.environ["OCI_OBJECT_PREFIX"]) / filename)
            _put_file(_par_object_url(os.environ["OCI_PAR_URL"], filename), temporary_name)
            return {"source_key": source_key, "target_date": target_date, "rows": count, "object": object_name}
        finally:
            if os.path.exists(temporary_name):
                os.remove(temporary_name)
