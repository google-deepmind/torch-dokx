#!/usr/bin/env python2.7
"""
Serve up search results as JSON via REST requests

Provide JSON results including the ID and the search snippet for given search
requests.

Ultimately needs to support advanced search as well, including NOT operators
and wildcards.
"""

import json
import sqlite3
import flask
import urllib
import argparse
import os
import sys
from dokxDaemon import Daemon

parser = argparse.ArgumentParser()
parser.add_argument("command", type=str, help="start|restart|stop")
parser.add_argument("--database", type=str, default=None, help="Path to SQLite3 search index")
parser.add_argument("--debug", type=bool, default=False, help="Debug mode")

args = parser.parse_args()

# Port on which JSON should be served up
PORT = 8130

app = flask.Flask(__name__)

@app.route("/search/<query>/")
@app.route("/search/<query>/<int:page>")
@app.route("/search/<query>/<int:page>/<int:limit>")
def search(query, page=0, limit=10):
    """Return JSON formatted search results, including snippets and facets"""

    query = urllib.unquote(query)
    results = __get_ranked_results(query, limit, page)
    count = __get_result_count(query)

    resj = json.dumps({
        'query': query,
        'results': results,
        'meta': {
            'total': count,
            'page': page,
            'limit': limit,
            'results': len(results)
        }
    })
    return flask.Response(response=str(resj), mimetype='application/json')

def __get_ranked_results(query, limit, page):
    """Simple search for terms, with optional limit and paging"""

    DB = sqlite3.connect(args.database)
    sql = """
            SELECT id, package, tag, doc, snippet(fulltext_search, "<b>", "</b>", "<b>...</b>", -1, -40) AS rank
            FROM fulltext_search
            WHERE fulltext_search MATCH ?
            ORDER BY rank DESC
            LIMIT ? OFFSET ?
    """

    cur = DB.execute(sql, (query, limit, page*limit))
    results = []
    for row in cur:
        results.append({
            'id': row[0],
            'package' : row[1],
            'tag' : row[2],
            'snippets': [row[4]]
        })

    return results

def __get_result_count(query):
    """Gather count of matching results"""

    DB = sqlite3.connect(args.database)
    sql = """
        SELECT COUNT(*) AS rescnt
        FROM fulltext_search
        WHERE fulltext_search MATCH ?
    """
    cur = DB.execute(sql, (query,))
    count = cur.fetchone()
    return count[0]

class RestDaemon(Daemon):
    def run(self):
        app.run(port=PORT)

if __name__ == "__main__":
    app.debug = args.debug
    pidFile = sys.argv[0] + ".pid"
    daemon = RestDaemon(pidFile)
    if args.command == 'start':
        daemon.start()
    elif args.command == 'restart':
        daemon.restart()
    elif args.command == 'stop':
        daemon.stop()
