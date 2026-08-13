import os
import asyncio
import logging
from functools import wraps
from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
from telethon import TelegramClient
from telethon.tl.types import DocumentAttributeVideo
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)

app = Flask(__name__)
CORS(app)

API_ID = int(os.getenv('API_ID'))
API_HASH = os.getenv('API_HASH')
PHONE = os.getenv('PHONE')
API_KEY = os.getenv('API_KEY')

client = TelegramClient('tg_session', API_ID, API_HASH)

def require_api_key(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        key = request.headers.get('X-API-Key') or request.args.get('key')
        if key != API_KEY:
            return jsonify({'error': 'Invalid API key'}), 401
        return f(*args, **kwargs)
    return decorated

def run_async(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()

def extract_video_info(message):
    result = {
        'msg_id': message.id,
        'date': int(message.date.timestamp()) if message.date else 0,
        'text': message.text or '',
        'has_video': False,
        'duration': '',
        'size': ''
    }
    if message.video or (message.document and message.document.mime_type
            and message.document.mime_type.startswith('video')):
        result['has_video'] = True
        if message.document:
            for attr in message.document.attributes:
                if isinstance(attr, DocumentAttributeVideo):
                    s = int(attr.duration)
                    result['duration'] = f"{s//3600}:{(s%3600)//60:02d}:{s%60:02d}"
            size = message.document.size
            if size:
                result['size'] = (f"{size/1073741824:.1f} GB"
                                  if size > 1073741824
                                  else f"{size/1048576:.1f} MB")
    return result

@app.route('/')
def home():
    return jsonify({'status': 'ok', 'service': 'Tele Cinema Bot'})

@app.route('/health')
def health():
    return jsonify({
        'connected': client.is_connected(),
        'authorized': run_async(client.is_user_authorized())
    })

@app.route('/channel/<username>')
@require_api_key
def get_channel(username):
    username = username.replace('@', '')
    limit = int(request.args.get('limit', 200))

    async def fetch():
        try:
            entity = await client.get_entity(username)
            messages = await client.get_messages(entity, limit=limit)
            results = [extract_video_info(m) for m in messages
                       if m.video or (m.text and len(m.text) > 5)]
            return {
                'title': getattr(entity, 'title', username),
                'username': username,
                'messages': results
            }
        except Exception as e:
            logging.error(f"Error: {e}")
            return {'error': str(e), 'messages': []}

    return jsonify(run_async(fetch()))

@app.route('/stream/<username>/<int:msg_id>')
@require_api_key
def stream_video(username, msg_id):
    username = username.replace('@', '')

    async def fetch():
        entity = await client.get_entity(username)
        msg = await client.get_messages(entity, ids=msg_id)
        if msg and (msg.video or msg.document):
            path = f"/tmp/stream_{username}_{msg_id}.mp4"
            await client.download_media(msg, path)
            return path
        return None

    path = run_async(fetch())
    if not path or not os.path.exists(path):
        return 'Not found', 404
    return send_file(path, mimetype='video/mp4')

def start_client():
    async def init():
        await client.start(phone=PHONE)
        print("✅ Telegram client started!")
    run_async(init())

if __name__ == '__main__':
    start_client()
    app.run(host='0.0.0.0', port=5000)
