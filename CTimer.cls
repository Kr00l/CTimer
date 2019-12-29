VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CTimer"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByRef Destination As Any, ByRef Source As Any, ByVal Length As Long)
Private Declare Function GetModuleHandle Lib "kernel32" Alias "GetModuleHandleW" (ByVal lpModuleName As Long) As Long
Private Declare Function GetProcAddress Lib "kernel32" (ByVal hModule As Long, ByVal lpProcName As String) As Long
Private Declare Function VirtualAlloc Lib "kernel32" (ByRef lpAddress As Long, ByVal dwSize As Long, ByVal flAllocType As Long, ByVal flProtect As Long) As Long
Private Declare Function VirtualFree Lib "kernel32" (ByRef lpAddress As Long, ByVal dwSize As Long, ByVal dwFreeType As Long) As Long
Private Declare Function GetTickCount Lib "kernel32" () As Long
Private Declare Function SetTimer Lib "user32" (ByVal hWnd As Long, ByVal nIDEvent As Long, ByVal uElapse As Long, ByVal lpTimerFunc As Long) As Long
Private Declare Function KillTimer Lib "user32" (ByVal hWnd As Long, ByVal nIDEvent As Long) As Long
Private Const MEM_COMMIT As Long = &H1000
Private Const MEM_RELEASE As Long = &H8000&
Private Const PAGE_EXECUTE_READWRITE As Long = &H40
Private Const PATCH_EBMODE As Long = 3
Private Const PATCH_STARTTIME As Long = 21
Private Const PATCH_KEY As Long = 36
Private Const PATCH_OBJECTPOINTER As Long = 41
Private Const PATCH_KILLTIMER As Long = 61
Private ASMWrapper As Long
Private PropOwner As ITimer, PropID As Long
Private PropKey As String
Private PropInterval As Long

Private Sub Class_Initialize()
Dim ASM(0 To 66) As Byte
ASM(0) = &HEB: ASM(1) = &HE: ASM(2) = &HE8: ASM(3) = &H0: ASM(4) = &H0
ASM(5) = &H0: ASM(6) = &H0: ASM(7) = &H83: ASM(8) = &HF8: ASM(9) = &H2
ASM(10) = &H74: ASM(11) = &H27: ASM(12) = &H85: ASM(13) = &HC0: ASM(14) = &H74
ASM(15) = &H26: ASM(16) = &H8B: ASM(17) = &H44: ASM(18) = &H24: ASM(19) = &H10
ASM(20) = &H2D: ASM(21) = &H0: ASM(22) = &H0: ASM(23) = &H0: ASM(24) = &H0
ASM(25) = &H99: ASM(26) = &HBB: ASM(27) = &H10: ASM(28) = &H27: ASM(29) = &H0
ASM(30) = &H0: ASM(31) = &HF7: ASM(32) = &HE3: ASM(33) = &H52: ASM(34) = &H50
ASM(35) = &H68: ASM(36) = &H0: ASM(37) = &H0: ASM(38) = &H0: ASM(39) = &H0
ASM(40) = &HB8: ASM(41) = &H0: ASM(42) = &H0: ASM(43) = &H0: ASM(44) = &H0
ASM(45) = &H50: ASM(46) = &H8B: ASM(47) = &H0: ASM(48) = &HFF: ASM(49) = &H50
ASM(50) = &H1C: ASM(51) = &HC2: ASM(52) = &H10: ASM(53) = &H0: ASM(54) = &H8B
ASM(55) = &H4C: ASM(56) = &H24: ASM(57) = &HC: ASM(58) = &H51: ASM(59) = &H50
ASM(60) = &HE8: ASM(61) = &H0: ASM(62) = &H0: ASM(63) = &H0: ASM(64) = &H0
ASM(65) = &HEB: ASM(66) = &HF0
ASMWrapper = VirtualAlloc(ByVal 0&, 104, MEM_COMMIT, PAGE_EXECUTE_READWRITE)
If ASMWrapper <> 0 Then
    CopyMemory ByVal ASMWrapper, ASM(0), 67
    If App.LogMode = 0 Then
        CopyMemory ByVal ASMWrapper, &H9090, 2
        Call PatchProcAddress(ASMWrapper, PATCH_EBMODE, "vba6.dll", "EbMode")
    End If
    Call PatchProcAddress(ASMWrapper, PATCH_KILLTIMER, "user32.dll", "KillTimer")
End If
End Sub

Private Sub Class_Terminate()
If PropID <> 0 Then Me.Terminate
If ASMWrapper <> 0 Then VirtualFree ByVal ASMWrapper, 0, MEM_RELEASE
End Sub

Public Function Create(ByVal Owner As ITimer, Optional ByVal Key As String) As Boolean
Attribute Create.VB_Description = "Creates a new timer."
If PropID <> 0 Then Err.Raise Number:=5, Description:="Timer already created"
If Owner Is Nothing Then Err.Raise Number:=380, Description:="Required argument is missing"
Set PropOwner = Owner
PropKey = Key
Call CreateTimer
Create = CBool(PropID <> 0)
End Function

Public Function Terminate() As Boolean
Attribute Terminate.VB_Description = "Terminates the current timer."
If PropID = 0 Then Err.Raise Number:=5, Description:="Timer must be created before it can be used"
Call DestroyTimer
Set PropOwner = Nothing
PropKey = vbNullString
Terminate = CBool(PropID = 0)
End Function

Public Property Get Interval() As Long
Attribute Interval.VB_Description = "Returns/sets the number of milliseconds between calls to a timer event."
Interval = PropInterval
End Property

Public Property Let Interval(ByVal Value As Long)
If Value < 0 Then Err.Raise 380
PropInterval = Value
Call DestroyTimer
Call CreateTimer
End Property

Public Property Get ID() As Long
Attribute ID.VB_Description = "Returns an internal identification of a timer."
Attribute ID.VB_UserMemId = 0
ID = PropID
End Property

Private Sub CreateTimer()
If PropID <> 0 Or ASMWrapper = 0 Then Exit Sub
If Not PropOwner Is Nothing And PropInterval > 0 Then
    MemOffset32(ASMWrapper, PATCH_STARTTIME) = GetTickCount()
    MemOffset32(ASMWrapper, PATCH_KEY) = StrPtr(PropKey)
    MemOffset32(ASMWrapper, PATCH_OBJECTPOINTER) = ObjPtr(PropOwner)
    PropID = SetTimer(0, 0, PropInterval, ASMWrapper)
End If
End Sub

Private Sub DestroyTimer()
If PropID = 0 Then Exit Sub
KillTimer 0, PropID
PropID = 0
End Sub

Private Sub PatchProcAddress(ByVal ASMWrapper As Long, ByVal Offset As Long, ByVal LibName As String, ByVal ProcName As String)
Dim ProcAddress As Long
ProcAddress = GetProcAddress(GetModuleHandle(StrPtr(LibName)), ProcName)
If ProcAddress <> 0 Then MemOffset32(ASMWrapper, Offset) = UnsignedAdd(ProcAddress, -UnsignedAdd(ASMWrapper, Offset) - 4)
End Sub

Private Property Get MemOffset32(ByVal Start As Long, ByVal Offset As Long) As Long
CopyMemory MemOffset32, ByVal UnsignedAdd(Start, Offset), 4
End Property

Private Property Let MemOffset32(ByVal Start As Long, ByVal Offset As Long, ByVal Value As Long)
CopyMemory ByVal UnsignedAdd(Start, Offset), Value, 4
End Property

Private Function UnsignedAdd(ByVal Start As Long, ByVal Incr As Long) As Long
UnsignedAdd = ((Start Xor &H80000000) + Incr) Xor &H80000000
End Function
