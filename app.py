# app.py
# Edited file to Trigger the webhook
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    build_version = os.environ.get('BUILD_VERSION', 'Unknown')
    return f"Hello from the Python App! Built by Jenkins. Version: {build_version}\n"

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

