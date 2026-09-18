# scratch/write_vbs.py
import sys

vbs_code = """' ====================================================================
' Universal Filename Cleaner Utility (VBScript)
' Автоматически очищает имена файлов в той папке, где запущен скрипт.
' Удаляет из названий: '_region', '_font_point', '_polyline', '_text'
' ====================================================================

Option Explicit

Dim objFSO, strFolderPath, strScriptName, intRenamedCount
Set objFSO = CreateObject("Scripting.FileSystemObject")

strFolderPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
strScriptName = WScript.ScriptName
intRenamedCount = 0

ProcessFolder strFolderPath

MsgBox "Очистка имён файлов завершена!" & vbCrLf & vbCrLf & _
       "Текущая папка: " & strFolderPath & vbCrLf & _
       "Переименовано файлов: " & intRenamedCount, _
       64, "Очистка имён файлов"

Sub ProcessFolder(ByVal path)
    Dim folder, file, subFolder, fileName, newFileName, oldFilePath, newFilePath
    On Error Resume Next
    Set folder = objFSO.GetFolder(path)
    If Err.Number <> 0 Then Exit Sub
    
    For Each file In folder.Files
        fileName = file.Name
        
        If LCase(fileName) <> LCase(strScriptName) Then
            If InStr(1, fileName, "_region", 1) > 0 Or _
               InStr(1, fileName, "_font_point", 1) > 0 Or _
               InStr(1, fileName, "_polyline", 1) > 0 Or _
               InStr(1, fileName, "_text", 1) > 0 Then
               
                newFileName = fileName
                newFileName = Replace(newFileName, "_region", "", 1, -1, 1)
                newFileName = Replace(newFileName, "_font_point", "", 1, -1, 1)
                newFileName = Replace(newFileName, "_polyline", "", 1, -1, 1)
                newFileName = Replace(newFileName, "_text", "", 1, -1, 1)
                
                If newFileName <> fileName Then
                    oldFilePath = file.Path
                    newFilePath = objFSO.BuildPath(folder.Path, newFileName)
                    If Not objFSO.FileExists(newFilePath) Then
                        objFSO.MoveFile oldFilePath, newFilePath
                        If Err.Number = 0 Then intRenamedCount = intRenamedCount + 1 Else Err.Clear
                    End If
                End If
            End If
        End If
    Next
    
    For Each subFolder In folder.SubFolders
        ProcessFolder subFolder.Path
    Next
    On Error GoTo 0
End Sub
"""

with open(r"C:\Users\рс\Desktop\Clean_Filenames.vbs", "wb") as f:
    f.write(vbs_code.encode("cp1251"))

print("Clean_Filenames.vbs saved in Windows-1251 encoding!")
