Attribute VB_Name = "JDPlanner"
Option Explicit
Public Silent As Boolean
Public Result As String

Private Sub Tell(ByVal message As String)
    Result = message
    ThisWorkbook.Worksheets("Dashboard_Menu").Range("B3").Value = message
    If Not Silent Then MsgBox message, vbInformation, "Synthetic Maintenance Planner"
End Sub

Private Function T(ByVal sheet As String, ByVal name As String) As ListObject
    Set T = ThisWorkbook.Worksheets(sheet).ListObjects(name)
End Function

Private Function Matches(ByVal r As Range, ByVal value As Variant) As Long
    Dim cell As Range
    If r Is Nothing Or IsError(value) Then Exit Function
    For Each cell In r
        If Not IsError(cell.Value) Then
            If StrComp(CStr(cell.Value), CStr(value), vbBinaryCompare) = 0 Then Matches = Matches + 1
        End If
    Next cell
End Function

Private Function NumberOK(ByVal value As Variant) As Boolean
    If IsError(value) Or IsEmpty(value) Or VarType(value) = vbString Or VarType(value) = vbBoolean Then Exit Function
    If IsNumeric(value) Then NumberOK = (CDbl(value) >= 0)
End Function

Private Function DateOK(ByVal value As Variant) As Boolean
    If IsError(value) Or IsEmpty(value) Then Exit Function
    If Not IsDate(value) Then Exit Function
    DateOK = CDate(value) >= DateSerial(2026, 5, 1) And CDate(value) < DateSerial(2026, 11, 1)
End Function

Private Function Member(ByVal value As Variant, ByVal options As String) As Boolean
    If IsError(value) Then Exit Function
    Member = InStr(1, "|" & options & "|", "|" & CStr(value) & "|", vbBinaryCompare) > 0 And Len(CStr(value)) > 0
End Function

Private Function ValidSources() As Boolean
    Dim table As ListObject, row As Range, machine As ListObject, ids As Range, i As Long, status As String
    On Error GoTo Failed
    Set machine = T("Machine_Master", "tblMachines")
    Set ids = machine.ListColumns("Machine_ID").DataBodyRange
    If ids Is Nothing Then Err.Raise 5, , "Machine master is empty"
    For Each row In machine.DataBodyRange.Rows
        If IsError(row.Cells(1, 1).Value) Then Err.Raise 5, , "Machine_ID contains error"
        If Len(Trim$(CStr(row.Cells(1, 1).Value))) = 0 Or Matches(ids, row.Cells(1, 1).Value) <> 1 Then Err.Raise 5, , "Missing/duplicate machine"
        For i = 2 To 3
            If IsError(row.Cells(1, i).Value) Then Err.Raise 5, , "Invalid machine name/line"
            If Len(Trim$(CStr(row.Cells(1, i).Value))) = 0 Then Err.Raise 5, , "Missing machine name/line"
        Next i
        If Not Member(row.Cells(1, 4).Value, "High|Medium|Low") Then Err.Raise 5, , "Invalid criticality"
    Next row
    Set table = T("Maintenance_Input", "tblMaintenance")
    For Each row In table.DataBodyRange.Rows
        If IsError(row.Cells(1, 1).Value) Then Err.Raise 5, , "Invalid Maintenance_ID"
        If Len(Trim$(CStr(row.Cells(1, 1).Value))) = 0 Or Matches(table.ListColumns(1).DataBodyRange, row.Cells(1, 1).Value) <> 1 Then Err.Raise 5, , "Missing/duplicate Maintenance_ID"
        If Matches(ids, row.Cells(1, 2).Value) <> 1 Then Err.Raise 5, , "Unknown machine"
        If Not DateOK(row.Cells(1, 3).Value) Then Err.Raise 5, , "Maintenance date outside May-Oct 2026"
        If Not Member(row.Cells(1, 4).Value, "Preventive|Corrective|Inspection") Then Err.Raise 5, , "Invalid type"
        If Not NumberOK(row.Cells(1, 6).Value) Or Not NumberOK(row.Cells(1, 7).Value) Then Err.Raise 5, , "Invalid duration/downtime"
        If row.Cells(1, 4).Value = "Corrective" Then
            If IsError(row.Cells(1, 5).Value) Then Err.Raise 5, , "Invalid failure mode"
            If Len(Trim$(CStr(row.Cells(1, 5).Value))) = 0 Then Err.Raise 5, , "Corrective failure requires Failure_Mode"
        ElseIf row.Cells(1, 7).Value <> 0 Then
            Err.Raise 5, , "Unplanned downtime must be zero for non-corrective records"
        End If
        If Not Member(row.Cells(1, 8).Value, "Completed") Then Err.Raise 5, , "Maintenance event must be Completed"
    Next row
    Set table = T("PM_Schedule", "tblPM")
    For Each row In table.DataBodyRange.Rows
        If IsError(row.Cells(1, 1).Value) Then Err.Raise 5, , "Invalid PM_ID"
        If Len(Trim$(CStr(row.Cells(1, 1).Value))) = 0 Or Matches(table.ListColumns(1).DataBodyRange, row.Cells(1, 1).Value) <> 1 Then Err.Raise 5, , "Missing/duplicate PM_ID"
        If Matches(ids, row.Cells(1, 2).Value) <> 1 Then Err.Raise 5, , "Unknown PM machine"
        If IsError(row.Cells(1, 3).Value) Then Err.Raise 5, , "Invalid PM_Type"
        If Len(Trim$(CStr(row.Cells(1, 3).Value))) = 0 Then Err.Raise 5, , "PM_Type required"
        If Not DateOK(row.Cells(1, 4).Value) Then Err.Raise 5, , "Due_Date outside May-Oct 2026"
        If Not Member(row.Cells(1, 6).Value, "Planned|Completed|Cancelled") Then Err.Raise 5, , "Invalid PM status"
        status = CStr(row.Cells(1, 6).Value)
        If status = "Completed" Then
            If Not DateOK(row.Cells(1, 5).Value) Then Err.Raise 5, , "Completed PM requires completion date in observation period"
        Else
            If IsError(row.Cells(1, 5).Value) Then Err.Raise 5, , "Invalid completion date"
            If Len(CStr(row.Cells(1, 5).Value)) > 0 Then Err.Raise 5, , "Only Completed PM may have completion date"
        End If
    Next row
    ValidSources = True
    Exit Function
Failed:
    Tell "FAIL: " & Err.Description
End Function

Public Sub ValidateSubmit()
    Dim ws As Worksheet, table As ListObject, id As String, n As Long, row As ListRow, i As Long
    On Error GoTo Failed
    If Not ValidSources() Then Exit Sub
    Set ws = ThisWorkbook.Worksheets("Dashboard_Menu")
    If Application.CountA(ws.Range("B8:B15")) = 0 Then Tell "PASS: all source tables are valid.": Exit Sub
    Set table = T("Maintenance_Input", "tblMaintenance")
    id = Trim$(CStr(ws.Range("B8").Value))
    If id = "" Then
        id = "MT-" & Format$(Now, "yyyymmddhhnnss")
        Do While Matches(table.ListColumns(1).DataBodyRange, id) > 0
            n = n + 1: id = "MT-" & Format$(Now, "yyyymmddhhnnss") & "-" & n
        Loop
    End If
    If Matches(table.ListColumns(1).DataBodyRange, id) > 0 Then Tell "Rejected: duplicate ID": Exit Sub
    If Matches(T("Machine_Master", "tblMachines").ListColumns(1).DataBodyRange, ws.Range("B9").Value) <> 1 Then Tell "Rejected: Machine_ID": Exit Sub
    If Not DateOK(ws.Range("B10").Value) Then Tell "Rejected: date must be within May-Oct 2026": Exit Sub
    If Not Member(ws.Range("B11").Value, "Preventive|Corrective|Inspection") Then Tell "Rejected: Type": Exit Sub
    If Not NumberOK(ws.Range("B13").Value) Or Not NumberOK(ws.Range("B14").Value) Then Tell "Rejected: numeric duration/downtime >= 0 required": Exit Sub
    If Not Member(ws.Range("B15").Value, "Completed") Then Tell "Rejected: Status must be Completed": Exit Sub
    If ws.Range("B11").Value = "Corrective" Then
        If Len(Trim$(CStr(ws.Range("B12").Value))) = 0 Then Tell "Rejected: Failure_Mode required": Exit Sub
    ElseIf ws.Range("B14").Value <> 0 Then
        Tell "Rejected: non-corrective unplanned downtime must be zero": Exit Sub
    End If
    Set row = table.ListRows.Add
    row.Range.Cells(1, 1).Value = id
    For i = 2 To 8: row.Range.Cells(1, i).Value = ws.Cells(i + 7, 2).Value: Next i
    ws.Range("B8:B15").ClearContents
    Tell "Saved: " & id
    Exit Sub
Failed:
    If Not row Is Nothing Then row.Delete
    Tell "Submit failed: " & Err.Description
End Sub

Public Sub RefreshPMStatus()
    Dim row As Range, cutoff As Variant, days As Long, status As String
    On Error GoTo Failed
    If Not ValidSources() Then Exit Sub
    cutoff = ThisWorkbook.Worksheets("Dashboard_Menu").Range("B18").Value
    If Not IsDate(cutoff) Then Tell "Invalid reporting date": Exit Sub
    For Each row In T("PM_Schedule", "tblPM").DataBodyRange.Rows
        status = row.Cells(1, 6).Value
        days = DateDiff("d", CDate(cutoff), CDate(row.Cells(1, 4).Value))
        If status <> "Completed" And status <> "Cancelled" Then
            If days < 0 Then status = "Overdue" Else If days <= 7 Then status = "Due Soon" Else status = "Upcoming"
        End If
        row.Cells(1, 7).Value = status
        row.Cells(1, 8).Value = days
    Next row
    Tell "PM refreshed. Reporting date: " & Format$(cutoff, "yyyy-mm-dd")
    Exit Sub
Failed:
    Tell "PM failed: " & Err.Description
End Sub

Private Function Quote(ByVal value As Variant) As String
    Quote = """" & Replace(CStr(value), """", """""") & """"
End Function

Public Sub ExportData()
    Dim fso As Object, root As String, folder As String, partial As String, stream As Object, log As ListObject
    Dim sheets As Variant, tables As Variant, files As Variant, sizes As Variant
    Dim table As ListObject, i As Long, j As Long, row As Range, line As String, value As Variant, n As Long
    On Error GoTo Failed
    If Not ValidSources() Then Exit Sub
    Set fso = CreateObject("Scripting.FileSystemObject")
    root = fso.GetParentFolderName(ThisWorkbook.Path) & "\exports"
    If Not fso.FolderExists(root) Then fso.CreateFolder root
    folder = root & "\" & Format$(Now, "yyyymmdd_hhnnss")
    Do While fso.FolderExists(folder) Or fso.FolderExists(folder & ".partial")
        n = n + 1: folder = root & "\" & Format$(Now, "yyyymmdd_hhnnss") & "_" & n
    Loop
    partial = folder & ".partial": fso.CreateFolder partial
    sheets = Array("Machine_Master", "Maintenance_Input", "PM_Schedule")
    tables = Array("tblMachines", "tblMaintenance", "tblPM")
    files = Array("machines.csv", "maintenance_records.csv", "pm_schedule.csv")
    sizes = Array(4, 8, 6)
    For i = 0 To 2
        Set table = T(CStr(sheets(i)), CStr(tables(i)))
        Set stream = CreateObject("ADODB.Stream")
        stream.Type = 2: stream.Charset = "utf-8": stream.Open
        line = ""
        For j = 1 To sizes(i)
            If j > 1 Then line = line & ","
            line = line & Quote(table.HeaderRowRange.Cells(1, j).Value)
        Next j
        stream.WriteText line & vbCrLf
        For Each row In table.DataBodyRange.Rows
            line = ""
            For j = 1 To sizes(i)
                value = row.Cells(1, j).Value
                If i = 1 And j = 3 Then
                    value = Format$(value, "yyyy-mm-dd hh:nn:ss")
                ElseIf i = 2 And (j = 4 Or j = 5) And Len(CStr(value)) > 0 Then
                    value = Format$(value, "yyyy-mm-dd")
                ElseIf i = 1 And (j = 6 Or j = 7) Then
                    value = Trim$(Str$(CDbl(value)))
                End If
                If j > 1 Then line = line & ","
                line = line & Quote(value)
            Next j
            stream.WriteText line & vbCrLf
        Next row
        stream.SaveToFile partial & "\" & files(i), 1: stream.Close
    Next i
    fso.MoveFolder partial, folder
    Set log = T("Export_Log", "tblExportLog")
    For i = 0 To 2
        Set row = log.ListRows.Add.Range
        row.Cells(1, 1).Value = Now: row.Cells(1, 2).Value = files(i)
        row.Cells(1, 3).Value = T(CStr(sheets(i)), CStr(tables(i))).ListRows.Count
        row.Cells(1, 4).Value = "SUCCESS": row.Cells(1, 5).Value = folder
    Next i
    Tell "Exported 3 CSVs: " & folder
    Exit Sub
Failed:
    Tell "Export failed: " & Err.Description & ". Do not load .partial folders."
End Sub
