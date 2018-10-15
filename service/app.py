import os

from flask import Flask, send_from_directory, request, redirect


app = Flask(__name__)
app.config['CONTENT_DIRECTORY'] = os.path.dirname(os.path.abspath(__file__))
app.config['UPLOADS_DIRECTORY'] = os.path.join(app.config['CONTENT_DIRECTORY'], "uploads")
app.config['UPLOAD_FILE'] = os.path.join(app.config['UPLOADS_DIRECTORY'], 'upload.jpg')
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0

if not os.path.exists(app.config['UPLOADS_DIRECTORY']):
    os.makedirs(app.config['UPLOADS_DIRECTORY'])


@app.route('/')
def homepage():
    return send_from_directory('static', 'index.html')


@app.route('/static/<path:path>')
def send_static(path):
    return send_from_directory('static', path)


@app.route('/api/v1', methods=['POST'])
def upload():
    try:
        file = request.files['file']
        file.save(app.config['UPLOAD_FILE'])
    except Exception as e:
        print(e)
    # TODO: Return a meaningful JSON response.
    return redirect('/')


@app.route('/api/v1', methods=['GET'])
def download():
    return send_from_directory(app.config['UPLOADS_DIRECTORY'], 'upload.jpg')


if __name__ == '__main__':
    app.run(host='0.0.0.0')

