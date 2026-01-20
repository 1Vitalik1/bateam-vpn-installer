#!/usr/bin/env python3
"""
VPN Management Web UI
Flask application for managing OpenVPN, Shadowsocks, V2Ray configurations
"""

from flask import Flask, render_template, request, jsonify, send_file, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import os
import subprocess
import redis
import json
import bcrypt
from datetime import datetime
import qrcode
from io import BytesIO
import base64

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'change-this-secret-key')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Redis connection
redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)

# Login manager
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Simple user class
class User(UserMixin):
    def __init__(self, id):
        self.id = id

@login_manager.user_loader
def load_user(user_id):
    return User(user_id)

# Helper functions
def verify_password(password, hashed):
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def hash_password(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def run_command(command):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr
        }
    except Exception as e:
        return {
            'success': False,
            'output': '',
            'error': str(e)
        }

def get_service_status(service_name):
    """Get status of a service"""
    try:
        result = run_command(f"docker ps --filter name={service_name} --format '{{{{.Status}}}}'")
        return 'running' if result['success'] and result['output'] else 'stopped'
    except:
        return 'unknown'

def generate_qr_code(data):
    """Generate QR code image"""
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    buffer = BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)
    return base64.b64encode(buffer.getvalue()).decode()

# Routes
@app.route('/')
@login_required
def index():
    """Dashboard"""
    services = {
        'openvpn': get_service_status('openvpn-server'),
        'shadowsocks': get_service_status('shadowsocks-server'),
        'v2ray': get_service_status('v2ray-server'),
        'stunnel': get_service_status('stunnel-wrapper'),
        'dnscrypt': get_service_status('dnscrypt-proxy'),
        'dpi-bypass': get_service_status('dpi-bypass')
    }
    
    # Get client count
    try:
        clients = redis_client.smembers('vpn:clients')
        client_count = len(clients)
    except:
        client_count = 0
    
    return render_template('dashboard.html', services=services, client_count=client_count)

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        # Simple authentication (in production use proper user management)
        admin_password = os.getenv('ADMIN_PASSWORD', 'admin123')
        
        if username == 'admin' and password == admin_password:
            user = User('admin')
            login_user(user)
            return redirect(url_for('index'))
        else:
            flash('Invalid credentials', 'error')
    
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/clients')
@login_required
def clients():
    """List all clients"""
    try:
        client_names = redis_client.smembers('vpn:clients')
        clients_data = []
        
        for name in client_names:
            client_info = redis_client.hgetall(f'vpn:client:{name}')
            clients_data.append({
                'name': name,
                'created': client_info.get('created', 'N/A'),
                'protocol': client_info.get('protocol', 'OpenVPN')
            })
        
        return render_template('clients.html', clients=clients_data)
    except Exception as e:
        flash(f'Error loading clients: {str(e)}', 'error')
        return render_template('clients.html', clients=[])

@app.route('/api/client/create', methods=['POST'])
@login_required
def create_client():
    """Create new client configuration"""
    data = request.get_json()
    client_name = data.get('name')
    protocol = data.get('protocol', 'openvpn')
    
    if not client_name:
        return jsonify({'success': False, 'error': 'Client name is required'}), 400
    
    # Check if client already exists
    if redis_client.sismember('vpn:clients', client_name):
        return jsonify({'success': False, 'error': 'Client already exists'}), 400
    
    # Generate configuration based on protocol
    if protocol == 'openvpn':
        result = run_command(f"docker exec openvpn-server /usr/local/bin/generate-client.sh {client_name}")
    elif protocol == 'shadowsocks':
        # Shadowsocks uses the same config for all clients, just different passwords
        result = {'success': True, 'output': 'Shadowsocks config generated'}
    elif protocol == 'v2ray':
        result = {'success': True, 'output': 'V2Ray config uses shared UUID'}
    else:
        return jsonify({'success': False, 'error': 'Invalid protocol'}), 400
    
    if result['success']:
        # Save client info in Redis
        redis_client.sadd('vpn:clients', client_name)
        redis_client.hset(f'vpn:client:{client_name}', mapping={
            'created': datetime.now().isoformat(),
            'protocol': protocol
        })
        
        return jsonify({
            'success': True,
            'message': f'Client {client_name} created successfully'
        })
    else:
        return jsonify({
            'success': False,
            'error': result['error']
        }), 500

@app.route('/api/client/<name>/download')
@login_required
def download_client_config(name):
    """Download client configuration file"""
    if not redis_client.sismember('vpn:clients', name):
        return jsonify({'success': False, 'error': 'Client not found'}), 404
    
    config_path = f'/etc/openvpn/client/{name}.ovpn'
    
    if os.path.exists(config_path):
        return send_file(config_path, as_attachment=True, download_name=f'{name}.ovpn')
    else:
        return jsonify({'success': False, 'error': 'Configuration file not found'}), 404

@app.route('/api/client/<name>/qr')
@login_required
def get_client_qr(name):
    """Get QR code for client configuration"""
    if not redis_client.sismember('vpn:clients', name):
        return jsonify({'success': False, 'error': 'Client not found'}), 404
    
    config_path = f'/etc/openvpn/client/{name}.ovpn'
    
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            config_data = f.read()
        
        qr_image = generate_qr_code(config_data)
        
        return jsonify({
            'success': True,
            'qr_code': qr_image
        })
    else:
        return jsonify({'success': False, 'error': 'Configuration file not found'}), 404

@app.route('/api/client/<name>/delete', methods=['DELETE'])
@login_required
def delete_client(name):
    """Delete client configuration"""
    if not redis_client.sismember('vpn:clients', name):
        return jsonify({'success': False, 'error': 'Client not found'}), 404
    
    # Revoke certificate
    result = run_command(f"docker exec openvpn-server /usr/local/share/easy-rsa/easyrsa revoke {name}")
    
    # Remove from Redis
    redis_client.srem('vpn:clients', name)
    redis_client.delete(f'vpn:client:{name}')
    
    return jsonify({
        'success': True,
        'message': f'Client {name} deleted successfully'
    })

@app.route('/api/stats')
@login_required
def get_stats():
    """Get server statistics"""
    stats = {
        'uptime': run_command("uptime -p")['output'].strip(),
        'clients_connected': 0,  # Would need to parse OpenVPN status
        'total_clients': len(redis_client.smembers('vpn:clients')),
        'services': {
            'openvpn': get_service_status('openvpn-server'),
            'shadowsocks': get_service_status('shadowsocks-server'),
            'v2ray': get_service_status('v2ray-server'),
            'stunnel': get_service_status('stunnel-wrapper'),
            'dnscrypt': get_service_status('dnscrypt-proxy'),
            'dpi-bypass': get_service_status('dpi-bypass')
        }
    }
    
    return jsonify(stats)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    # Initialize admin user if not exists
    if not redis_client.exists('user:admin'):
        admin_password = os.getenv('ADMIN_PASSWORD', 'admin123')
        redis_client.hset('user:admin', 'password', hash_password(admin_password))
    
    app.run(host='0.0.0.0', port=8080, debug=False)