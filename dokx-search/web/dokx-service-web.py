#!/usr/bin/env python2.7
"""
Simple search UI for SQLite3 full-text search
"""

import json
import flask
import os
import sys
import urllib
from jinja2 import Environment, FileSystemLoader
import argparse
from dokxDaemon import Daemon

parser = argparse.ArgumentParser()
parser.add_argument("command", type=str, help="start|restart|stop")
parser.add_argument("--docs", type=str, default=None, help="Path to HTML docs")
parser.add_argument("--debug", type=bool, default=False, help="Debug mode")

args = parser.parse_args()

JSON_HOST = "http://localhost:8130" # Where the restserv service is running
PORT = 5000

env = Environment(loader=FileSystemLoader(searchpath="%s/templates" % os.path.dirname((os.path.realpath(__file__)))), trim_blocks=True)
app = flask.Flask(__name__, static_folder=args.docs, static_url_path='')

@app.route("/")
def root():
    return app.send_static_file("index.html")

@app.route("/search")
def search():
    """Simple search for terms, with optional limit and paging"""
    query = flask.request.args.get('query', '')
    if not query:
        template = env.get_template('index.html')
        return template.render()

    page = flask.request.args.get('page', '')
    jsonu = u"%s/search/%s/" % (JSON_HOST, urllib.quote_plus(query.encode('utf-8')))
    if page:
        jsonu = u"%s%d" % (jsonu, int(page))
    res = json.loads(urllib.urlopen(jsonu).read().decode('utf-8'))
    template = env.get_template('results.html')
    return(template.render(
        terms=res['query'].replace('+', ' '),
        results=res,
        request=flask.request
    ))

class WebDaemon(Daemon):
    def run(self):
        app.run(port=PORT)

if __name__ == "__main__":
    app.debug = args.debug
    pidFile = sys.argv[0] + ".pid"
    daemon = WebDaemon(pidFile)
    if args.command == 'start':
        daemon.start()
    elif args.command == 'restart':
        daemon.restart()
    elif args.command == 'stop':
        daemon.stop()

