$TempPath = [System.IO.Path]::GetTempPath()
cd $TempPath
Expand-Archive -Force "$TempPath\QuickPatcher_Patch_v3.0.0+.zip"

