"""
Create and populate a minimal PostgreSQL schema for full text search
"""

import sqlite3
import glob
import os
import re

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=str, help="Path to write SQLite3 search index")
parser.add_argument('input', type=str, help="Path to input directory of Markdown files")
args = parser.parse_args()

DB_NAME = args.output
DB_HOST = 'localhost' # Uses a local socket
DB_USER = 'fts_user'

DB = sqlite3.connect(database=DB_NAME)

path = args.input

def load_db():
    """Add sample data to the database"""

    ins = """INSERT INTO fulltext_search(package, tag, doc) VALUES(?, ?, ?);"""

    pattern = re.compile('<a name="(.*)"></a>')

    for packageName in os.listdir(path):
        for filePath in glob.glob(os.path.join(path, packageName, "*.md")):
            print("Indexing " + filePath)
            with open(filePath, 'r') as f:
                section = ""
                tag = os.path.basename(filePath)
                for line in f.readlines():
                    result = pattern.match(line)
                    if result:
                        DB.execute(ins, (packageName, tag, section))
                        tag = result.group(1)
                        section = ""
                    else:
                        section += line
    DB.commit()

def init_db():
    """Initialize our database"""
    DB.execute("DROP TABLE IF EXISTS fulltext_search")
    DB.execute("""CREATE VIRTUAL TABLE fulltext_search USING fts4(
            id SERIAL,
            package TEXT,
            tag TEXT,
            doc TEXT,
            tokenize=porter
        );""")

if __name__ == "__main__":
    init_db()
    load_db()
    DB.close()
