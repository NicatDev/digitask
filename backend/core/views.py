import os
from django.conf import settings
from django.http import FileResponse, Http404
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny


class AppDownloadView(APIView):
    """
    Serves the latest Android APK file for download.
    APK files should be placed in MEDIA_ROOT/app/ directory.
    The latest APK is determined by file modification time.
    """
    permission_classes = [AllowAny]
    
    def get(self, request):
        app_dir = os.path.join(settings.MEDIA_ROOT, 'app')
        
        if not os.path.exists(app_dir):
            os.makedirs(app_dir, exist_ok=True)
            raise Http404("No APK available. Please upload an APK file.")
        
        # Find the latest APK file
        apk_files = [f for f in os.listdir(app_dir) if f.endswith('.apk')]
        
        if not apk_files:
            raise Http404("No APK available. Please build and upload the APK file.")
        
        # Get the most recently modified APK
        latest_apk = max(
            apk_files,
            key=lambda f: os.path.getmtime(os.path.join(app_dir, f))
        )
        
        apk_path = os.path.join(app_dir, latest_apk)
        
        response = FileResponse(
            open(apk_path, 'rb'),
            as_attachment=True,
            filename='DigiTask.apk'
        )
        response['Content-Type'] = 'application/vnd.android.package-archive'
        return response
