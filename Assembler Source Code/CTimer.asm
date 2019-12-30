; CTimer.cls model assembler source

; Runtime patch markers
%define _patch1_    01BCCAABh           ; Relative address to EbMode (vba6.dll)
%define _patch2_    02BCCAABh           ; Start time (GetTickCount)
%define _patch3_    03BCCAABh           ; Key StrPtr()
%define _patch4_    04BCCAABh           ; Address of ITimer
%define _patch5_    05BCCAABh           ; Relative address to KillTimer (user32.dll)

; Stack frame
%define dwTime      [esp+16]            ; Milliseconds that have elapsed since the system was started (GetTickCount)
%define idTimer     [esp+12]            ; The timer's identifier

[bits 32]
    jmp     _callback                   ; Patched with two nop's if in the IDE
                                        ; Check to see if the IDE is on a breakpoint
    db      0E8h                        ; Far call op-code
    dd      _patch1_                    ; Call EbMode, the relative address to EbMode is patched at runtime
    cmp     eax, 2                      ; If EbMode returns 2 
    je      _return                     ;   The IDE is on a breakpoint
    test    eax, eax                    ; If EbMode returns 0
    je      _kill_tmr                   ;   The IDE has stopped

_callback:                              ; Call ITimer_Timer
    mov     eax, dwTime                 ; Prepare elapsed time calculation
    sub     dword eax, _patch2_         ; Calculate elapsed time, patched at runtime
    cdq                                 ; Convert Long to Currency
    mov     ebx, 10000                  ; Shift decimal point to the right
    mul     ebx
    push    edx
    push    eax                         ; ByVal ElapsedTime
    push    _patch3_                    ; ByVal Key
    mov     eax, _patch4_               ; Address of ITimer, patched at runtime
    push    eax                         ; Push address of ITimer
    mov     eax, [eax]                  ; Get the address of the VTable
    call    dword [eax+1Ch]            	; Call ITimer, VTable offset 1Ch

_return:    ;Cleanup and exit                                
    ret     16
    
_kill_tmr:                              ; The IDE has stopped, kill the timer and return
    mov     ecx, idTimer                ; Get the timer's identifier
    push    ecx                         ; Push the timer's identifier
    push    eax                         ; Push 0
    db      0E8h                        ; Far call
    dd      _patch5_                    ; Call KillTimer, patched at runtime
    jmp     _return