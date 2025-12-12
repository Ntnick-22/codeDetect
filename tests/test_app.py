"""Simple tests for CodeDetect application"""
import pytest
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))


def test_app_imports():
    """Test that the app module can be imported"""
    import app
    assert app is not None


def test_allowed_file_function():
    """Test the allowed_file function with .py files"""
    from app import allowed_file

    # Should accept .py files
    assert allowed_file('test.py') == True
    assert allowed_file('test.PY') == True

    # Should reject other files
    assert allowed_file('test.txt') == False
    assert allowed_file('test.jpg') == False


def test_health_endpoint():
    """Test that /api/health endpoint works"""
    from app import app

    with app.test_client() as client:
        response = client.get('/api/health')
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'healthy'


def test_info_endpoint():
    """Test that /api/info endpoint works"""
    from app import app

    with app.test_client() as client:
        response = client.get('/api/info')
        assert response.status_code == 200
        data = response.get_json()
        assert 'version' in data or 'docker_tag' in data


def test_app_config():
    """Test that basic app configuration exists"""
    from app import ALLOWED_EXTENSIONS, UPLOAD_FOLDER

    assert 'py' in ALLOWED_EXTENSIONS
    assert UPLOAD_FOLDER is not None
