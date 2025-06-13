; Ӳ�����Ӷ��� ; LCD������ RS
; Ӳ�����Ӷ���
; LCD������
RS      BIT P2.5     ; �Ĵ���ѡ��
RW      BIT P2.6     ; ��д����
EN      BIT P2.7     ; ʹ���ź�
; LCD������
LCD_DAT EQU P3       ; P1�˿�����D0-D7
; DS18B20
DQ      BIT P2.4     ; ��������������
ALARM   BIT P2.3     ; �����ź��������
; ��������
K1      BIT P1.0     ; ģʽ�л�
K2      BIT P1.1     ; ��1/�鿴����
K3      BIT P1.2     ; ��1/�鿴����
K4      BIT P1.3     ; �����л�/����������
; ������
BEEP    BIT P2.2     ; ���������

; ��������
TEMP_L  DATA 30H     ; �¶ȵ��ֽ�
TEMP_H  DATA 31H     ; �¶ȸ��ֽ�
DIGIT0  DATA 32H     ; ��λ����
DIGIT1  DATA 33H     ; ʮλ����
DIGIT2  DATA 34H     ; ��λ����
DIGIT3  DATA 35H     ; С��λ����
SIGN    DATA 36H     ; �¶ȷ���(0=��, 1=��)
OLD_MODE DATA 42H    ; ����֮ǰ������ģʽ��0=����,1=����,2=���ޣ�
KEY_TIMER   DATA 43H    ; ������ʱ��

; ����������
TEMP_HIGH_L DATA 37H ; �����¶ȵ��ֽ�
TEMP_HIGH_H DATA 38H ; �����¶ȸ��ֽ�
TEMP_LOW_L  DATA 39H ; �����¶ȵ��ֽ�
TEMP_LOW_H  DATA 3AH ; �����¶ȸ��ֽ�

RAW_TEMP_H  DATA 44H     ; ԭʼ���ֽڣ����룬����ר�ã�
RAW_TEMP_L  DATA 45H     ; ԭʼ���ֽڣ����룬����ר�ã�

; ģʽ��־��״̬
MODE    DATA 3BH     ; 0=����,1=������,2=������
BEEP_FLAG DATA 3CH   ; ��������־ (0=��,1=��)
VIEW_MODE DATA 3DH   ; �鿴ģʽ (0=����,1=����,2=����)
VIEW_CNT DATA 3EH    ; �鿴ģʽ������

; ����ģʽ��ʱ����
SET_TEMP_L DATA 3FH  ; �����¶ȵ��ֽ�
SET_TEMP_H DATA 40H  ; �����¶ȸ��ֽ�
SET_SIGN   DATA 41H  ; ���÷���

; �������
ORG 0000H
    LJMP MAIN

; ������
ORG 0100H
MAIN:
    MOV SP, #60H      ; ���ö�ջָ��
    ; ��ʼ������
    MOV MODE, #0       ; ����ģʽ
	MOV OLD_MODE, #0   ; ���OLD_MODE��ʼ��
    MOV BEEP_FLAG, #1  ; Ĭ�Ͽ���������
    MOV VIEW_MODE, #0  ; ������ʾ

	CLR ALARM   ; ����������
    CLR BEEP    ; �رշ�����

    ; ��ʼ������������ (Ĭ������38��C, ����-12��C)
    MOV TEMP_HIGH_L, #60H  ; 38��C: 0011 1000 0000 -> 0380H
    MOV TEMP_HIGH_H, #02H  ; ���ֽ�02H, ���ֽ�60H
    MOV TEMP_LOW_L, #040H  ; -12��C: 1111 0100 0000 -> F40H -> ���� FFC0H
    MOV TEMP_LOW_H, #0FFH  ; ���ֽ�FFH, ���ֽ�C0H
	MOV KEY_TIMER, #0   ; ��ʼ��������ʱ��
    
    LCALL LCD_INIT    ; ��ʼ��LCD
    LCALL LCD_CLEAR   ; ����
    
    ; ��ʾ����
    MOV DPTR, #TEXT_TITLE
    LCALL LCD_WRITE_STRING
    
LOOP:
    ; ��ȡ�¶� (��������ģʽ��)
    MOV A, MODE
    JNZ SKIP_READ  ; ����ģʽ�������¶ȶ�ȡ
    LCALL DS18B20_READ_TEMP
    ; ����ȡ�Ƿ�ɹ�
    JC READ_FAIL
    LCALL CONVERT_TEMP      ; ת���¶�ֵΪ����
    LJMP DISPLAY
READ_FAIL:
    ; ��ʾ������Ϣ
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_ERROR
    LCALL LCD_WRITE_STRING
    LJMP KEY_HANDLE

SKIP_READ:
    ; ����ģʽ��ֱ����ʾ
    LJMP DISPLAY

DISP_NORMAL:
    ; ����ģʽ��ʾ
    MOV A, VIEW_MODE
    JZ DISP_CURRENT   ; 0=��ʾ��ǰ�¶�
    DEC A
    JZ DISP_HIGH      ; 1=��ʾ����
    DEC A
    JZ DISP_LOW       ; 2=��ʾ����
    LJMP KEY_HANDLE

DISP_CURRENT:
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV R0, #16
    MOV A, #' '
CLEAR_LOOP:
    LCALL LCD_DATA
    DJNZ R0, CLEAR_LOOP    
    MOV A, #0C0H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    LJMP KEY_HANDLE

DISP_SET_HIGH:
    ; ��������ģʽ��ʾ
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_HIGH
    LCALL LCD_WRITE_STRING
    ; ��ʾ��ǰ����ֵ
    MOV A, #0C6H
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    LJMP KEY_HANDLE

DISP_HIGH:
    ; ��ʾ�����¶�
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_HIGH
    LCALL LCD_WRITE_STRING
    ; ���浱ǰ�¶Ⱥͷ���
    MOV A, TEMP_H
    PUSH ACC
    MOV A, TEMP_L
    PUSH ACC
    MOV A, SIGN
    PUSH ACC
    ; ʹ�������¶�
    MOV TEMP_H, TEMP_HIGH_H
    MOV TEMP_L, TEMP_HIGH_L
    MOV SIGN, #0
    MOV A, TEMP_HIGH_H
    ANL A, #80H
    JZ POS_HIGH
    MOV SIGN, #1

DISPLAY:
    ; ����ģʽѡ����ʾ����
    MOV A, MODE
    JZ DISP_NORMAL   ; 0=����ģʽ
    DEC A
    JZ DISP_SET_HIGH ; 1=������
    DEC A
    JZ DISP_SET_LOW  ; 2=������
    LJMP KEY_HANDLE

DISP_LOW:
    ; ��ʾ�����¶�
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_LOW
    LCALL LCD_WRITE_STRING
    
    ; ���浱ǰ�¶Ⱥͷ���
    MOV A, TEMP_H
    PUSH ACC
    MOV A, TEMP_L
    PUSH ACC
    MOV A, SIGN
    PUSH ACC
    
    ; ���������¶�
    MOV TEMP_H, TEMP_LOW_H
    MOV TEMP_L, TEMP_LOW_L
    
    ; ��ȷ�ж������¶ȵķ���
    MOV A, TEMP_LOW_H
    ANL A, #80H
    JZ POS_LOW_DISP
    MOV SIGN, #1      ; ���¶�
    SJMP CONV_LOW
POS_LOW_DISP:
    MOV SIGN, #0      ; ���¶�
CONV_LOW:
    LCALL CONVERT_TEMP
    
    ; ��ʾ�¶�ֵ
    MOV A, #0C6H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    
    ; �ָ�ԭֵ
    POP ACC
    MOV SIGN, A
    POP ACC
    MOV TEMP_L, A
    POP ACC
    MOV TEMP_H, A
    
    ; ����ת����ǰ�¶�
    LCALL CONVERT_TEMP
    SJMP KEY_HANDLE

DISP_SET_LOW:
    ; ��������ģʽ��ʾ
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_LOW
    LCALL LCD_WRITE_STRING
    ; ��ʾ��ǰ����ֵ
    MOV A, #0C6H
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP KEY_HANDLE
POS_HIGH:
    LCALL CONVERT_TEMP
    ; ��ʾ�¶�ֵ
    MOV A, #0C6H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    ; �ָ�ԭֵ
    POP ACC
    MOV SIGN, A
    POP ACC
    MOV TEMP_L, A
    POP ACC
    MOV TEMP_H, A
    ; ����ת����ǰ�¶��Ա������
    LCALL CONVERT_TEMP
    SJMP KEY_HANDLE



KEY_HANDLE:
    ; ����ɨ��
    LCALL KEY_SCAN1
    LCALL KEY_SCAN2
    LCALL KEY_SCAN3
    LCALL KEY_SCAN4
    
    ; �������
    LCALL CHECK_ALARM
    
    ; �޸ģ���������ģʽ�´���鿴ģʽ����
    MOV A, MODE
    JNZ SKIP_VIEW_CNT
    
    ; �鿴ģʽ����
    MOV A, VIEW_MODE
    JZ SKIP_VIEW_CNT
    MOV A, VIEW_CNT
    JZ RESET_VIEW
    DEC VIEW_CNT
    SJMP DELAY_LOOP

POS_LOW:
    LCALL CONVERT_TEMP
    ; ��ʾ�¶�ֵ
    MOV A, #0C6H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    ; �ָ�ԭֵ
    POP ACC
    MOV SIGN, A
    POP ACC
    MOV TEMP_L, A
    POP ACC
    MOV TEMP_H, A
    ; ����ת����ǰ�¶��Ա������
    LCALL CONVERT_TEMP
    SJMP KEY_HANDLE
RESET_VIEW:
    MOV VIEW_MODE, #0  ; ����������ʾ
    SJMP DELAY_LOOP

SKIP_VIEW_CNT:
    ; ����ģʽ�²�����鿴ģʽ����
    
DELAY_LOOP:
    ; ��ʱԼ0.5��
    MOV R0, #10
DELAY_500MS:
    MOV R1, #50
    MOV R2, #250
    DJNZ R2, $
    DJNZ R1, $-4
    DJNZ R0, $-8
    
    LJMP LOOP

; �ı�����
TEXT_TITLE: DB "Temperature:", 0
TEXT_DEG:   DB "C", 0
TEXT_ERROR: DB "Error!       ", 0
;TEXT_HIGH:  DB "HTemp:", 0
;TEXT_LOW:   DB "LTemp: ", 0
TEXT_SET_HIGH: DB "HTemp:", 0
TEXT_SET_LOW:  DB "LTemp: ", 0
TEXT_NORMAL:   DB "CTemp: ", 0

;===== �޸���İ������� (K1_PRESSED����) =====;
KEY_RET1:
    RET
KEY_SCAN1:
    ; ���K1
    JNB K1, K1_PRESSED
	MOV KEY_TIMER, #0   ; �����ͷ�ʱ���ü�ʱ��
    RET
   
K1_PRESSED:
	LCALL KEY_DELAY    
    INC KEY_TIMER
    MOV A, KEY_TIMER
    CJNE A, #1, KEY_RET1 ; δ�ﵽ����ʱ��

	; K1���ܣ�ģʽ�л�
    MOV KEY_TIMER, #0   ; ���ü�ʱ��
    LCALL BEEP_SHORT

    ; ���浱ǰģʽ��OLD_MODE
    MOV A, MODE
    MOV OLD_MODE, A
        
    ; �˳���ǰģʽʱ�������� (�ؼ��޸�)
    MOV A, OLD_MODE
    CJNE A, #1, CHECK_SAVE_LOW
    ; ������������
    MOV TEMP_HIGH_H, SET_TEMP_H
    MOV TEMP_HIGH_L, SET_TEMP_L
    SJMP DO_MODE_SWITCH
    
CHECK_SAVE_LOW:
    CJNE A, #2, DO_MODE_SWITCH
    ; ������������
    MOV TEMP_LOW_H, SET_TEMP_H
    MOV TEMP_LOW_L, SET_TEMP_L

DO_MODE_SWITCH:
    ; ѭ���л�ģʽ
    MOV A, MODE
    ADD A, #1
    CJNE A, #3, K1_MODE
    MOV A, #0        ; ����2��ص�0

K1_MODE:
    MOV MODE, A
    
    ; ������ģʽ�ĳ�ʼ��
    MOV A, MODE
    JZ K1_NORMAL    ; ����ģʽ
    
    CJNE A, #1, INIT_SET_LOW
    ; ��������ģʽ��ʼ�� - ���ص�ǰ����ֵ (�޸���)
    MOV SET_TEMP_L, TEMP_HIGH_L
    MOV SET_TEMP_H, TEMP_HIGH_H
    MOV SET_SIGN, #0
    MOV A, TEMP_HIGH_H
    ANL A, #80H
    JZ SET_HIGH_POS
    MOV SET_SIGN, #1
SET_HIGH_POS:
    SJMP K1_DISPLAY
    
INIT_SET_LOW:
    CJNE A, #2, K1_DISPLAY
    ; ��������ģʽ��ʼ�� - ���ص�ǰ����ֵ (�޸���)
    MOV SET_TEMP_L, TEMP_LOW_L
    MOV SET_TEMP_H, TEMP_LOW_H
    MOV SET_SIGN, #0
    MOV A, TEMP_LOW_H
    ANL A, #80H
    JZ SET_LOW_POS
    MOV SET_SIGN, #1

NOT_SET_HIGH:
    CJNE A, #2, K1_DISPLAY
    ; ��������ģʽ
    MOV SET_TEMP_L, TEMP_LOW_L
    MOV SET_TEMP_H, TEMP_LOW_H
    MOV SET_SIGN, #0
    MOV A, TEMP_LOW_H
    ANL A, #80H
    JZ SET_LOW_POS
    MOV SET_SIGN, #1
SET_LOW_POS:
 	SJMP K1_DISPLAY
K1_SAVE_SETTINGS:
    ; �˳�ʱ��������ֵ
    MOV A, OLD_MODE
    CJNE A, #1, SAVE_LOW
    ; ��������
    MOV TEMP_HIGH_H, SET_TEMP_H
    MOV TEMP_HIGH_L, SET_TEMP_L
    SJMP K1_BEEP
SAVE_LOW:
    MOV TEMP_LOW_H, SET_TEMP_H
    MOV TEMP_LOW_L, SET_TEMP_L

K1_NORMAL:
    ; ����ģʽ����Ҫ�����ʼ��
    RET
K1_DISPLAY:
    ; ��������ʾ��ǰģʽ
    LCALL LCD_CLEAR
    MOV A, #80H       ; ��һ����ʼ��ַ
    LCALL LCD_CMD
    MOV DPTR, #TEXT_TITLE
    LCALL LCD_WRITE_STRING
    
    ; ����ģʽ��ʾ��ͬ��ʾ
    MOV A, MODE
    JZ MODE_NORMAL
    CJNE A, #1, MODE_LOW
    
    ; ��������ģʽ��ʾ
    MOV A, #0C0H      ; �ڶ�����ʼ��ַ
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_HIGH
    LCALL LCD_WRITE_STRING
    ; ��ʾ��ǰ����ֵ
    MOV A, #0C6H      ; "HTemp:"��λ��
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP WAIT_FOR_RELEASE ; ��ת���ȴ��ͷ�
 
MODE_LOW:
    ; ��������ģʽ��ʾ
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_LOW
    LCALL LCD_WRITE_STRING
    ; ��ʾ��ǰ����ֵ
    MOV A, #0C6H      ; "LTemp:"��λ��
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP WAIT_FOR_RELEASE ; ��ת���ȴ��ͷ�


MODE_NORMAL:
    ; ����ģʽ��ʾ
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_NORMAL
    LCALL LCD_WRITE_STRING
WAIT_FOR_RELEASE:
    JNB K1, WAIT_FOR_RELEASE ; �ȴ������ͷ�
    RET
K1_BEEP:
    LCALL BEEP_SHORT
    JNB K1, $        ; �ȴ������ͷ�
    RET

KEY_RET2:
    RET
KEY_SCAN2:
    ; ���K2
    JNB K2, K2_PRESSED
    RET
K2_PRESSED:
    LCALL KEY_DELAY
    JB K2, KEY_RET2
    
    ; ����ģʽѡ����
    MOV A, MODE
    JZ K2_NORMAL        ; ����ģʽ
    
    ; ����ģʽ����1
    LCALL SET_INC
    ; ������ʾ
    MOV A, #0C6H        ; �¶���ʾλ��
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP K2_BEEP
;===== ����ɨ���ӳ��� =====;
K2_NORMAL:
    ; ����ģʽ���鿴����
    MOV VIEW_MODE, #1
    MOV VIEW_CNT, #2 ; ��ʾԼ1��(0.5s*2)
K2_BEEP:
    LCALL BEEP_SHORT
    JNB K2, $        ; �ȴ��ͷ�
    RET
KEY_RET3:
    RET
KEY_SCAN3:
    ; ���K3
    JNB K3, K3_PRESSED
    RET
K3_PRESSED:
    LCALL KEY_DELAY
    JB K3, KEY_RET3
    
    ; ����ģʽѡ����
    MOV A, MODE
    JZ K3_NORMAL        ; ����ģʽ
    
    ; ����ģʽ����1
    LCALL SET_DEC
    ; ������ʾ
    MOV A, #0C6H        ; �¶���ʾλ��
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP K3_BEEP
K3_NORMAL:
    ; ����ģʽ���鿴����
    MOV VIEW_MODE, #2
    MOV VIEW_CNT, #2 ; ��ʾԼ1��
K3_BEEP:
    LCALL BEEP_SHORT
    JNB K3, $        ; �ȴ��ͷ�
    RET


KEY_RET4:
    RET
KEY_SCAN4:
    ; ���K4
    JNB K4, K4_PRESSED
    RET
K4_PRESSED:
    LCALL KEY_DELAY
    JB K4, KEY_RET4
    
    ; ����ģʽѡ����
    MOV A, MODE
    JZ K4_NORMAL        ; ����ģʽ
    
    ; ����ģʽ���л�����
    MOV A, SET_SIGN
    CPL A
    MOV SET_SIGN, A
    ; ���·���
    LCALL SET_UPDATE_SIGN
    ; ������ʾ
    MOV A, #0C6H        ; �¶���ʾλ��
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP K4_BEEP
K4_NORMAL:
    ; ����ģʽ���л�������
    MOV A, BEEP_FLAG
    CPL A
    MOV BEEP_FLAG, A
K4_BEEP:
    LCALL BEEP_SHORT  ; ���ǵ��ã��ڲ������־
    JNB K4, $        ; �ȴ��ͷ�
    RET              ; �ؼ�����ӷ���ָ��
; ����������ʱ
KEY_DELAY:
    MOV R5, #10
    DJNZ R5, $
    RET

; �̷�����
BEEP_SHORT:
    MOV A, BEEP_FLAG
    JZ NO_BEEP
    
    ; �����̴ٵ�"��"��
    SETB BEEP
    ; �㹻������ʱ (Լ5ms)
    MOV R6, #10

BEEP_DELAY1:
    MOV R7, #250
    DJNZ R7, $
    DJNZ R6, BEEP_DELAY1
    CLR BEEP      ; ȷ��������ر�

NO_BEEP:
    RET

;===== ����ģʽ�Ӽ����� =====;
SET_INC:
    ; ����ֵ��1 (��������)
    MOV A, SET_SIGN
    JNZ SET_INC_NEG
    ; ������1
    MOV A, SET_TEMP_L
    ADD A, #16      ; ��1��C (16����С��λ)
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    ADDC A, #0
    MOV SET_TEMP_H, A
    ; �������(125��C)
    MOV A, SET_TEMP_H
    JNZ SET_INC_CHECK
    MOV A, SET_TEMP_L
    CJNE A, #0D0H, SET_INC_CHECK  ; 125*16=2000(07D0H)
    JC SET_INC_CHECK
    ; ��������
    MOV SET_TEMP_L, #0D0H  ; 125��C
    MOV SET_TEMP_H, #07H
    SJMP SET_INC_END

SET_INC_CHECK:
    ; ����Ƿ�Ӹ�����
    MOV A, SET_TEMP_H
    ANL A, #80H
    JZ SET_INC_END   ; ��������
    ; ���ű仯(������)
    MOV SET_SIGN, #0
    SJMP SET_INC_END

SET_INC_NEG:
    ; ������1(����ֵ��С)
    MOV A, SET_TEMP_L
    ADD A, #16
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    ADDC A, #0
    MOV SET_TEMP_H, A
    ; ����Ƿ��Ϊ����
    MOV A, SET_TEMP_H
    ANL A, #80H
    JNZ SET_INC_END
    ; ���ű仯(������)
    MOV SET_SIGN, #0

SET_INC_END:
    RET

SET_DEC:
    ; ����ֵ��1 (��������)
    MOV A, SET_SIGN
    JZ SET_DEC_POS
    ; ������1(����ֵ����)
    MOV A, SET_TEMP_L
    CLR C
    SUBB A, #16
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    SUBB A, #0
    MOV SET_TEMP_H, A
    ; �������(-55��C)
    MOV A, SET_TEMP_H
    CJNE A, #0FFH, SET_DEC_CHECK
    MOV A, SET_TEMP_L
    CJNE A, #0B0H, SET_DEC_CHECK  ; -55*16=-880(FC90H)
    JNC SET_DEC_CHECK
    ; ��������
    MOV SET_TEMP_L, #90H  ; -55��C
    MOV SET_TEMP_H, #0FCH
    RET

SET_DEC_CHECK:
    ; ����Ƿ�����为
    MOV A, SET_TEMP_H
    ANL A, #80H
    JNZ SET_DEC_END   ; ���Ǹ���
    ; ���ű仯(���为)
    MOV SET_SIGN, #1
    SJMP SET_DEC_END

SET_DEC_POS:
    ; ������1
    MOV A, SET_TEMP_L
    CLR C
    SUBB A, #16
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    SUBB A, #0
    MOV SET_TEMP_H, A
    ; ����Ƿ��Ϊ����
    MOV A, SET_TEMP_H
    ANL A, #80H
    JZ SET_DEC_END
    ; ���ű仯(���为)
    MOV SET_SIGN, #1

SET_DEC_END:
    RET

; ��������ģʽ�µķ���
;===== �޸���ķ��Ÿ����ӳ��� =====;
SET_UPDATE_SIGN:
    MOV A, SET_SIGN
    JNZ SET_POSITIVE
    
    ; ��ת����ȡ���� (�Ƴ������ORL)
    MOV A, SET_TEMP_L
    CPL A
    ADD A, #1
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    CPL A
    ADDC A, #0
    MOV SET_TEMP_H, A    ; ע�⣺�����Ƴ��� ORL A,#80H
    RET

SET_POSITIVE:
    ; ��ת����ȡ���� (�Ƴ������ANL)
    MOV A, SET_TEMP_L
    CPL A
    ADD A, #1
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    CPL A
    ADDC A, #0
    MOV SET_TEMP_H, A    ; ע�⣺�����Ƴ��� ANL A,#7FH
    RET

;===== ��������ӳ��� =====;
CHECK_ALARM:
    ; ���浱ǰ�¶ȵ�ԭʼֵ���ڱȽ�
    MOV A, RAW_TEMP_H
    MOV R2, A
    MOV A, RAW_TEMP_L
    MOV R3, A
    
    ; �Ƚ����޺�������ȷ��ģʽ
    CLR C
    MOV A, TEMP_HIGH_H
    SUBB A, TEMP_LOW_H
    JNZ CHECK_MODE
    MOV A, TEMP_HIGH_L
    SUBB A, TEMP_LOW_L
CHECK_MODE:
    JC REVERSE_MODE    ; �������<���ޣ���ת������ģʽ
    
    ; ����ģʽ (����>����)
    ; �ȼ���Ƿ��������
    CLR C
    MOV A, R3          ; ��ǰ�¶ȵ��ֽ�
    SUBB A, TEMP_LOW_L
    MOV A, R2          ; ��ǰ�¶ȸ��ֽ�
    SUBB A, TEMP_LOW_H
    JC ALARM_ON        ; �����ǰ�¶� < ���ޣ�����
    
    ; �ټ���Ƿ��������
    CLR C
    MOV A, TEMP_HIGH_L
    SUBB A, R3         ; ��ǰ�¶ȵ��ֽ�
    MOV A, TEMP_HIGH_H
    SUBB A, R2         ; ��ǰ�¶ȸ��ֽ�
    JC ALARM_ON        ; �����ǰ�¶� > ���ޣ�����
    SJMP ALARM_OFF     ; �ڷ�Χ�ڣ��رձ���
    
REVERSE_MODE:
    ; ����ģʽ (����>����)
    ; ����Ƿ��ڱ��������� (���� < ��ǰ�¶� < ����)
    
    ; �ȼ���Ƿ��������
    CLR C
    MOV A, TEMP_HIGH_L
    SUBB A, R3         ; ��ǰ�¶ȵ��ֽ�
    MOV A, TEMP_HIGH_H
    SUBB A, R2         ; ��ǰ�¶ȸ��ֽ�
    JNC ALARM_OFF      ; �����ǰ�¶� <= ���ޣ�������
    
    ; �ټ���Ƿ��������
    CLR C
    MOV A, R3          ; ��ǰ�¶ȵ��ֽ�
    SUBB A, TEMP_LOW_L
    MOV A, R2          ; ��ǰ�¶ȸ��ֽ�
    SUBB A, TEMP_LOW_H
    JNC ALARM_OFF      ; �����ǰ�¶� >= ���ޣ�������
    
ALARM_ON:
    SETB ALARM         ; �����������
    RET

ALARM_OFF:
    CLR ALARM          ; �رձ������
    RET


;===== LCD�����ӳ��� =====; 
; LCD��ʼ��
LCD_INIT:
    MOV A, #38H      ; 8λģʽ, 2��, 5x7����
    LCALL LCD_CMD
    MOV A, #0CH      ; ��ʾ��, ����, ��˸��
    LCALL LCD_CMD
    MOV A, #06H      ; ��ַ����, ������
    LCALL LCD_CMD
    RET

; �������LCD
LCD_CMD:
    CLR RS           ; ����ģʽ
    CLR RW           ; д����
    MOV LCD_DAT, A   ; ��������
    SETB EN          ; ʹ������
    CLR EN
    LCALL DELAY_2MS  ; ��ʱ�ȴ�
    RET

; �������ݵ�LCD
LCD_DATA:
    SETB RS          ; ����ģʽ
    CLR RW           ; д����
    MOV LCD_DAT, A   ; ��������
    SETB EN          ; ʹ������
    CLR EN
    LCALL DELAY_2MS  ; ��ʱ�ȴ�
    RET

; ����
LCD_CLEAR:
    MOV A, #01H      ; ��������
    LCALL LCD_CMD
    RET

; ��ʾ�ַ���(DPTRָ���ַ���)
LCD_WRITE_STRING:
    CLR A
    MOVC A, @A+DPTR  ; ȡ�ַ�
    JZ WS_END        ; ����0����
    LCALL LCD_DATA   ; ��ʾ�ַ�
    INC DPTR         ; ָ����һ��
    SJMP LCD_WRITE_STRING
WS_END:
    RET

;===== DS18B20�����ӳ��� =====;
; ��ʼ��DS18B20
DS18B20_INIT:
    CLR DQ           ; ��������
    MOV R6, #250     ; ��ʱ480us (12MHz)
    DJNZ R6, $
    SETB DQ          ; �ͷ�����
    MOV R6, #30      ; ��ʱ60us
    DJNZ R6, $
    
    ; ���Ӧ���ź�
    JB DQ, INIT_FAIL ; ��Ӧ��
    MOV R6, #240     ; �ȴ������������
    DJNZ R6, $
    SETB DQ          ; �ͷ�����
    CLR C            ; �ɹ���־
    RET
    
INIT_FAIL:
    SETB DQ          ; �ͷ�����
    SETB C            ; ʧ�ܱ�־
    RET

; дһ���ֽڵ�DS18B20 (A��Ϊ����)
DS18B20_WRITE:
    MOV R7, #8       ; 8λ����
WRITE_BIT:
    CLR DQ           ; ��ʼдʱ϶
    MOV R6, #4       ; ��ʱ8us
    DJNZ R6, $
    RRC A            ; �Ƴ����λ
    MOV DQ, C        ; ����λ
    MOV R6, #24      ; ��ʱ48us
    DJNZ R6, $
    SETB DQ          ; �ͷ�����
    DJNZ R7, WRITE_BIT
    SETB DQ          ; �ͷ�����
    RET

; ��DS18B20��ȡһ���ֽ� (�����A)
DS18B20_READ:
    MOV R7, #8       ; 8λ����
READ_BIT:
    CLR DQ           ; ��ʼ��ʱ϶
    MOV R6, #2       ; ��ʱ4us
    DJNZ R6, $
    SETB DQ          ; �ͷ�����
    MOV R6, #4       ; ��ʱ8us
    DJNZ R6, $
    MOV C, DQ        ; ��ȡλ
    RRC A            ; ����A
    MOV R6, #24      ; ��ʱ48us
    DJNZ R6, $
    DJNZ R7, READ_BIT
    RET

; ��ȡ�¶�ֵ
DS18B20_READ_TEMP:
    LCALL DS18B20_INIT ; ��ʼ��
    ;JC READ_FAIL      ; ʧ�ܴ���
    
    MOV A, #0CCH      ; ����ROM����
    LCALL DS18B20_WRITE
    MOV A, #44H       ; ��ʼ�¶�ת��
    LCALL DS18B20_WRITE
    
    ; �ȴ�ת����� (750ms)
    MOV R0, #150
WAIT_CONV:
    LCALL DELAY_5MS
    DJNZ R0, WAIT_CONV
    
    LCALL DS18B20_INIT ; ���³�ʼ��
    JC READ_FAILEND
    
    MOV A, #0CCH      ; ����ROM
    LCALL DS18B20_WRITE
    MOV A, #0BEH      ; ���ݴ�������
    LCALL DS18B20_WRITE
    
    LCALL DS18B20_READ ; ���¶ȵ��ֽ�
    MOV TEMP_L, A
    MOV RAW_TEMP_L, A  ; ����ԭʼ����
    LCALL DS18B20_READ ; ���¶ȸ��ֽ�
    MOV TEMP_H, A
    MOV RAW_TEMP_H, A  ; ����ԭʼ����
    CLR C
    RET

READ_FAILEND:
    SETB C            ; ���ô����־
    RET

;===== �¶ȴ����ӳ��� =====;
; ת���¶�ֵΪ����
CONVERT_TEMP:
    MOV A, TEMP_H
    ANL A, #80H
    JZ POSITIVE
    
    ; ���¶ȴ�������תԭ�룩
    MOV SIGN, #1
    MOV A, TEMP_L
    CPL A
    ADD A, #1
    MOV TEMP_L, A
    MOV A, TEMP_H
    CPL A
    ADDC A, #0
    ANL A, #7FH       ; �������λ
    MOV TEMP_H, A
    SJMP CONV_CONT
    
POSITIVE:
    MOV SIGN, #0
    ; ȷ�����¶ȸ�λ�޷�����չ
    MOV A, TEMP_H
    ANL A, #0FH
    MOV TEMP_H, A
    
CONV_CONT:
    ; ��ȡ��������
    MOV A, TEMP_H
    ANL A, #0FH       ; ȡ��Ч��4λ
    MOV B, #16        ; ����4λ (��16)
    MUL AB
    MOV R0, A         ; �ݴ���
    
    MOV A, TEMP_L
    SWAP A            ; �����ߵ�4λ
    ANL A, #0FH       ; ȡ��4λ
    ADD A, R0         ; ��ϳ���������
    MOV R1, A         ; �����������ֵ�R1
    
    ; �����λ��ʮλ����λ
    MOV B, #100
    DIV AB            ; A=��λ, B=����
    MOV DIGIT0, A     ; �洢��λ
    
    MOV A, B          ; ����(0-99)
    MOV B, #10
    DIV AB            ; A=ʮλ, B=��λ
    MOV DIGIT1, A
    MOV DIGIT2, B
    
    ; С�����ִ���
    MOV A, TEMP_L
    ANL A, #0FH       ; ȡ��4λ (С������)
    MOV B, #6         ; 0.0625 �� 100 �� 6
    MUL AB
    MOV A, B          ; ȡ�������� (0-9)
    MOV DIGIT3, A
    
    RET

; ��ʾ�¶�
DISPLAY_TEMP:
    ; ��ʾ����
    MOV A, SIGN
    JZ DISP_POS
    MOV A, #'-'       ; ����
    LCALL LCD_DATA
    SJMP DISP_DIGITS
    
DISP_POS:
    MOV A, #' '       ; �ո�
    LCALL LCD_DATA
    
DISP_DIGITS:
    ; ��ʾ��λ�������Ϊ0��
    MOV A, DIGIT0
    JZ NO_HUNDRED     ; �����λΪ0����ʾ
    ADD A, #30H       ; ת��ΪASCII
    LCALL LCD_DATA
    SJMP DISP_TENS
    
NO_HUNDRED:
    ; ��λΪ0ʱ��ʾ�ո�
    MOV A, #' '
    LCALL LCD_DATA

DISP_TENS:
    ; ��ʾʮλ
    MOV A, DIGIT1
    ADD A, #30H
    LCALL LCD_DATA
    
    ; ��ʾ��λ
    MOV A, DIGIT2
    ADD A, #30H
    LCALL LCD_DATA
    
    ; ��ʾС����
    MOV A, #'.'
    LCALL LCD_DATA
    
    ; ��ʾС��λ
    MOV A, DIGIT3
    ADD A, #30H
    LCALL LCD_DATA
    
    ; ��ʾ��λ
    MOV DPTR, #TEXT_DEG
    LCALL LCD_WRITE_STRING
    
    RET

;===== ��ʱ�ӳ��� =====;
; 0.8ms��ʱ
DELAY_2MS:
    MOV R3, #10
DL1: MOV R4, #80
    DJNZ R4, $
    DJNZ R3, DL1
    RET

; 1ms��ʱ
DELAY_5MS:
    MOV R5, #5
DL2: LCALL DELAY_2MS
    DJNZ R5, DL2
    RET
END