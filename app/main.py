import os
import socket
import sys

import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)


def db_connect():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "db"),
        port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
    )


@app.errorhandler(psycopg2.Error)
def database_error(exc):
    app.logger.error("database error: %s", exc)
    return jsonify(error="database unavailable"), 503


@app.get("/")
def index():
    conn = db_connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("INSERT INTO visits DEFAULT VALUES")
            cur.execute("SELECT count(*) FROM visits")
            total = cur.fetchone()[0]
    finally:
        conn.close()
    return jsonify(service="web", visits=total, served_by=socket.gethostname())


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


@app.get("/health")
def health():
    conn = db_connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
    finally:
        conn.close()
    return jsonify(status="ok", database="up")


@app.get("/info")
def info():
    return jsonify(
        uid=os.getuid(),
        gid=os.getgid(),
        hostname=socket.gethostname(),
        python=sys.version.split()[0],
    )
