;-------------------------------------------------------------------------------
; 	<FindHostIP>
;-------------------------------------------------------------------------------
; Parameters
;	pServerName		pointer to a string containing the server
;					name to resolve	the IP number for.
; Return value 
;  	IP number in network byte order or NULL if the hostname
;	was not found.
FindHostIP	proc uses ebx pServerName:dword
	invoke	gethostbyname, [pServerName]
	test	eax, eax
	jz		_return
	; eax is a pointer to a HOSTENT structure now,
	; get first address list pointer in list:
	mov		eax, [(hostent ptr [eax]).h_list]
	test	eax, eax
	jz		_return
	; get first address pointer in list:
	mov		eax, [eax]
	test	eax, eax
	jz		_return
	; get first address from pointer
	mov		eax, [eax]
	; eax is IP number now, fall through so IP gets returned
_return:
	ret
FindHostIP	endp



;-------------------------------------------------------------------------------
; <FillSockAddr>
;-------------------------------------------------------------------------------
; Parameters
;	pSockAddr		pointer to the sockaddr_in structure to fill
;	pServerName		pointer to a string containing the server
;					name to address
;	portNumber		address port number
; Return value 
;  	0:		host lookup failed
;	not 0:	function succeeded
FillSockAddr proc pSockAddr:dword, pServerName:dword, portNumber:dword

	invoke	FindHostIP, [pServerName]
	test	eax, eax
	jz		_done
	
	mov		edx, [pSockAddr]
	mov		ecx, [portNumber]
	xchg 	cl, ch	; convert to network byte order
	
	mov		[edx][sockaddr_in.sin_family], AF_INET	
	mov		[edx][sockaddr_in.sin_port], cx
	mov		[edx][sockaddr_in.sin_addr.S_un.S_addr], eax
		
_done:
	ret
FillSockAddr endp	

;-------------------------------------------------------------------------------
; <FThread>
;-------------------------------------------------------------------------------
; Parameters
;	FCParams		pointer to forward structure
;Returns nothing - works in infinite loop.

FThread proc pFCParams:dword
local Fbuffer[1024]:byte, nBytesRec:dword, nBytesSend:dword;
	.WHILE TRUE
		invoke ZeroMemory, addr Fbuffer, sizeof Fbuffer;
		mov edx, pFCParams	   
	    mov ebx, [edx]
		invoke recv, ebx,addr Fbuffer, sizeof Fbuffer,0
		
		mov nBytesRec,eax 
		.IF eax == SOCKET_ERROR
			.IF  DBG_OUTPUT == 1
				invoke	printf, addr g_errLocalConn
			.ENDIF
			;invoke printf addr g_errLocalConn
			invoke ExitProcess, 0;
		.ENDIF
		.IF eax > 0
			.IF  DBG_OUTPUT == 1
				invoke	printf, addr g_msgncoming
			.ENDIF
		.ENDIF
		mov edx, pFCParams
		mov ebx, [edx+4]
		invoke sendto, ebx, addr Fbuffer, nBytesRec, 0, pFCParams+8, sizeof pFCParams+8;
		.IF eax == SOCKET_ERROR
			;invoke ExitProcess, 0;
		.ENDIF
		invoke Sleep, 1
	.ENDW
	ret
FThread endp
