; 硬件连接定义 ; LCD控制线 RS
; 硬件连接定义
; LCD控制线
RS      BIT P2.5     ; 寄存器选择
RW      BIT P2.6     ; 读写控制
EN      BIT P2.7     ; 使能信号
; LCD数据线
LCD_DAT EQU P3       ; P1端口连接D0-D7
; DS18B20
DQ      BIT P2.4     ; 单总线数据引脚
ALARM   BIT P2.3     ; 报警信号输出引脚
; 按键定义
K1      BIT P1.0     ; 模式切换
K2      BIT P1.1     ; 加1/查看上限
K3      BIT P1.2     ; 减1/查看下限
K4      BIT P1.3     ; 正负切换/按键音开关
; 蜂鸣器
BEEP    BIT P2.2     ; 按键音输出

; 变量定义
TEMP_L  DATA 30H     ; 温度低字节
TEMP_H  DATA 31H     ; 温度高字节
DIGIT0  DATA 32H     ; 百位数字
DIGIT1  DATA 33H     ; 十位数字
DIGIT2  DATA 34H     ; 个位数字
DIGIT3  DATA 35H     ; 小数位数字
SIGN    DATA 36H     ; 温度符号(0=正, 1=负)
OLD_MODE DATA 42H    ; 保存之前的设置模式（0=正常,1=上限,2=下限）
KEY_TIMER   DATA 43H    ; 按键计时器

; 报警上下限
TEMP_HIGH_L DATA 37H ; 上限温度低字节
TEMP_HIGH_H DATA 38H ; 上限温度高字节
TEMP_LOW_L  DATA 39H ; 下限温度低字节
TEMP_LOW_H  DATA 3AH ; 下限温度高字节

RAW_TEMP_H  DATA 44H     ; 原始高字节（补码，报警专用）
RAW_TEMP_L  DATA 45H     ; 原始低字节（补码，报警专用）

; 模式标志和状态
MODE    DATA 3BH     ; 0=正常,1=设上限,2=设下限
BEEP_FLAG DATA 3CH   ; 按键音标志 (0=关,1=开)
VIEW_MODE DATA 3DH   ; 查看模式 (0=正常,1=看上,2=看下)
VIEW_CNT DATA 3EH    ; 查看模式计数器

; 设置模式临时变量
SET_TEMP_L DATA 3FH  ; 设置温度低字节
SET_TEMP_H DATA 40H  ; 设置温度高字节
SET_SIGN   DATA 41H  ; 设置符号

; 程序入口
ORG 0000H
    LJMP MAIN

; 主程序
ORG 0100H
MAIN:
    MOV SP, #60H      ; 设置堆栈指针
    ; 初始化变量
    MOV MODE, #0       ; 正常模式
	MOV OLD_MODE, #0   ; 添加OLD_MODE初始化
    MOV BEEP_FLAG, #1  ; 默认开启按键音
    MOV VIEW_MODE, #0  ; 正常显示

	CLR ALARM   ; 清除报警输出
    CLR BEEP    ; 关闭蜂鸣器

    ; 初始化报警上下限 (默认上限38°C, 下限-12°C)
    MOV TEMP_HIGH_L, #60H  ; 38°C: 0011 1000 0000 -> 0380H
    MOV TEMP_HIGH_H, #02H  ; 高字节02H, 低字节60H
    MOV TEMP_LOW_L, #040H  ; -12°C: 1111 0100 0000 -> F40H -> 补码 FFC0H
    MOV TEMP_LOW_H, #0FFH  ; 高字节FFH, 低字节C0H
	MOV KEY_TIMER, #0   ; 初始化按键计时器
    
    LCALL LCD_INIT    ; 初始化LCD
    LCALL LCD_CLEAR   ; 清屏
    
    ; 显示标题
    MOV DPTR, #TEXT_TITLE
    LCALL LCD_WRITE_STRING
    
LOOP:
    ; 读取温度 (仅在正常模式下)
    MOV A, MODE
    JNZ SKIP_READ  ; 设置模式下跳过温度读取
    LCALL DS18B20_READ_TEMP
    ; 检查读取是否成功
    JC READ_FAIL
    LCALL CONVERT_TEMP      ; 转换温度值为数字
    LJMP DISPLAY
READ_FAIL:
    ; 显示错误信息
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_ERROR
    LCALL LCD_WRITE_STRING
    LJMP KEY_HANDLE

SKIP_READ:
    ; 设置模式下直接显示
    LJMP DISPLAY

DISP_NORMAL:
    ; 正常模式显示
    MOV A, VIEW_MODE
    JZ DISP_CURRENT   ; 0=显示当前温度
    DEC A
    JZ DISP_HIGH      ; 1=显示上限
    DEC A
    JZ DISP_LOW       ; 2=显示下限
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
    ; 上限设置模式显示
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_HIGH
    LCALL LCD_WRITE_STRING
    ; 显示当前设置值
    MOV A, #0C6H
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    LJMP KEY_HANDLE

DISP_HIGH:
    ; 显示上限温度
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_HIGH
    LCALL LCD_WRITE_STRING
    ; 保存当前温度和符号
    MOV A, TEMP_H
    PUSH ACC
    MOV A, TEMP_L
    PUSH ACC
    MOV A, SIGN
    PUSH ACC
    ; 使用上限温度
    MOV TEMP_H, TEMP_HIGH_H
    MOV TEMP_L, TEMP_HIGH_L
    MOV SIGN, #0
    MOV A, TEMP_HIGH_H
    ANL A, #80H
    JZ POS_HIGH
    MOV SIGN, #1

DISPLAY:
    ; 根据模式选择显示内容
    MOV A, MODE
    JZ DISP_NORMAL   ; 0=正常模式
    DEC A
    JZ DISP_SET_HIGH ; 1=设上限
    DEC A
    JZ DISP_SET_LOW  ; 2=设下限
    LJMP KEY_HANDLE

DISP_LOW:
    ; 显示下限温度
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_LOW
    LCALL LCD_WRITE_STRING
    
    ; 保存当前温度和符号
    MOV A, TEMP_H
    PUSH ACC
    MOV A, TEMP_L
    PUSH ACC
    MOV A, SIGN
    PUSH ACC
    
    ; 加载下限温度
    MOV TEMP_H, TEMP_LOW_H
    MOV TEMP_L, TEMP_LOW_L
    
    ; 正确判断下限温度的符号
    MOV A, TEMP_LOW_H
    ANL A, #80H
    JZ POS_LOW_DISP
    MOV SIGN, #1      ; 负温度
    SJMP CONV_LOW
POS_LOW_DISP:
    MOV SIGN, #0      ; 正温度
CONV_LOW:
    LCALL CONVERT_TEMP
    
    ; 显示温度值
    MOV A, #0C6H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    
    ; 恢复原值
    POP ACC
    MOV SIGN, A
    POP ACC
    MOV TEMP_L, A
    POP ACC
    MOV TEMP_H, A
    
    ; 重新转换当前温度
    LCALL CONVERT_TEMP
    SJMP KEY_HANDLE

DISP_SET_LOW:
    ; 下限设置模式显示
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_LOW
    LCALL LCD_WRITE_STRING
    ; 显示当前设置值
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
    ; 显示温度值
    MOV A, #0C6H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    ; 恢复原值
    POP ACC
    MOV SIGN, A
    POP ACC
    MOV TEMP_L, A
    POP ACC
    MOV TEMP_H, A
    ; 重新转换当前温度以避免残留
    LCALL CONVERT_TEMP
    SJMP KEY_HANDLE



KEY_HANDLE:
    ; 按键扫描
    LCALL KEY_SCAN1
    LCALL KEY_SCAN2
    LCALL KEY_SCAN3
    LCALL KEY_SCAN4
    
    ; 报警检查
    LCALL CHECK_ALARM
    
    ; 修改：仅在正常模式下处理查看模式计数
    MOV A, MODE
    JNZ SKIP_VIEW_CNT
    
    ; 查看模式计数
    MOV A, VIEW_MODE
    JZ SKIP_VIEW_CNT
    MOV A, VIEW_CNT
    JZ RESET_VIEW
    DEC VIEW_CNT
    SJMP DELAY_LOOP

POS_LOW:
    LCALL CONVERT_TEMP
    ; 显示温度值
    MOV A, #0C6H
    LCALL LCD_CMD
    LCALL DISPLAY_TEMP
    ; 恢复原值
    POP ACC
    MOV SIGN, A
    POP ACC
    MOV TEMP_L, A
    POP ACC
    MOV TEMP_H, A
    ; 重新转换当前温度以避免残留
    LCALL CONVERT_TEMP
    SJMP KEY_HANDLE
RESET_VIEW:
    MOV VIEW_MODE, #0  ; 返回正常显示
    SJMP DELAY_LOOP

SKIP_VIEW_CNT:
    ; 设置模式下不处理查看模式计数
    
DELAY_LOOP:
    ; 延时约0.5秒
    MOV R0, #10
DELAY_500MS:
    MOV R1, #50
    MOV R2, #250
    DJNZ R2, $
    DJNZ R1, $-4
    DJNZ R0, $-8
    
    LJMP LOOP

; 文本定义
TEXT_TITLE: DB "Temperature:", 0
TEXT_DEG:   DB "C", 0
TEXT_ERROR: DB "Error!       ", 0
;TEXT_HIGH:  DB "HTemp:", 0
;TEXT_LOW:   DB "LTemp: ", 0
TEXT_SET_HIGH: DB "HTemp:", 0
TEXT_SET_LOW:  DB "LTemp: ", 0
TEXT_NORMAL:   DB "CTemp: ", 0

;===== 修复后的按键处理 (K1_PRESSED部分) =====;
KEY_RET1:
    RET
KEY_SCAN1:
    ; 检测K1
    JNB K1, K1_PRESSED
	MOV KEY_TIMER, #0   ; 按键释放时重置计时器
    RET
   
K1_PRESSED:
	LCALL KEY_DELAY    
    INC KEY_TIMER
    MOV A, KEY_TIMER
    CJNE A, #1, KEY_RET1 ; 未达到长按时间

	; K1功能：模式切换
    MOV KEY_TIMER, #0   ; 重置计时器
    LCALL BEEP_SHORT

    ; 保存当前模式到OLD_MODE
    MOV A, MODE
    MOV OLD_MODE, A
        
    ; 退出当前模式时保存设置 (关键修复)
    MOV A, OLD_MODE
    CJNE A, #1, CHECK_SAVE_LOW
    ; 保存上限设置
    MOV TEMP_HIGH_H, SET_TEMP_H
    MOV TEMP_HIGH_L, SET_TEMP_L
    SJMP DO_MODE_SWITCH
    
CHECK_SAVE_LOW:
    CJNE A, #2, DO_MODE_SWITCH
    ; 保存下限设置
    MOV TEMP_LOW_H, SET_TEMP_H
    MOV TEMP_LOW_L, SET_TEMP_L

DO_MODE_SWITCH:
    ; 循环切换模式
    MOV A, MODE
    ADD A, #1
    CJNE A, #3, K1_MODE
    MOV A, #0        ; 超过2则回到0

K1_MODE:
    MOV MODE, A
    
    ; 进入新模式的初始化
    MOV A, MODE
    JZ K1_NORMAL    ; 正常模式
    
    CJNE A, #1, INIT_SET_LOW
    ; 上限设置模式初始化 - 加载当前上限值 (修复点)
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
    ; 下限设置模式初始化 - 加载当前下限值 (修复点)
    MOV SET_TEMP_L, TEMP_LOW_L
    MOV SET_TEMP_H, TEMP_LOW_H
    MOV SET_SIGN, #0
    MOV A, TEMP_LOW_H
    ANL A, #80H
    JZ SET_LOW_POS
    MOV SET_SIGN, #1

NOT_SET_HIGH:
    CJNE A, #2, K1_DISPLAY
    ; 下限设置模式
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
    ; 退出时保存设置值
    MOV A, OLD_MODE
    CJNE A, #1, SAVE_LOW
    ; 保存上限
    MOV TEMP_HIGH_H, SET_TEMP_H
    MOV TEMP_HIGH_L, SET_TEMP_L
    SJMP K1_BEEP
SAVE_LOW:
    MOV TEMP_LOW_H, SET_TEMP_H
    MOV TEMP_LOW_L, SET_TEMP_L

K1_NORMAL:
    ; 正常模式不需要额外初始化
    RET
K1_DISPLAY:
    ; 清屏并显示当前模式
    LCALL LCD_CLEAR
    MOV A, #80H       ; 第一行起始地址
    LCALL LCD_CMD
    MOV DPTR, #TEXT_TITLE
    LCALL LCD_WRITE_STRING
    
    ; 根据模式显示不同提示
    MOV A, MODE
    JZ MODE_NORMAL
    CJNE A, #1, MODE_LOW
    
    ; 上限设置模式提示
    MOV A, #0C0H      ; 第二行起始地址
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_HIGH
    LCALL LCD_WRITE_STRING
    ; 显示当前设置值
    MOV A, #0C6H      ; "HTemp:"后位置
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP WAIT_FOR_RELEASE ; 跳转到等待释放
 
MODE_LOW:
    ; 下限设置模式提示
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_SET_LOW
    LCALL LCD_WRITE_STRING
    ; 显示当前设置值
    MOV A, #0C6H      ; "LTemp:"后位置
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP WAIT_FOR_RELEASE ; 跳转到等待释放


MODE_NORMAL:
    ; 正常模式提示
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #TEXT_NORMAL
    LCALL LCD_WRITE_STRING
WAIT_FOR_RELEASE:
    JNB K1, WAIT_FOR_RELEASE ; 等待按键释放
    RET
K1_BEEP:
    LCALL BEEP_SHORT
    JNB K1, $        ; 等待按键释放
    RET

KEY_RET2:
    RET
KEY_SCAN2:
    ; 检测K2
    JNB K2, K2_PRESSED
    RET
K2_PRESSED:
    LCALL KEY_DELAY
    JB K2, KEY_RET2
    
    ; 根据模式选择功能
    MOV A, MODE
    JZ K2_NORMAL        ; 正常模式
    
    ; 设置模式：加1
    LCALL SET_INC
    ; 更新显示
    MOV A, #0C6H        ; 温度显示位置
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP K2_BEEP
;===== 按键扫描子程序 =====;
K2_NORMAL:
    ; 正常模式：查看上限
    MOV VIEW_MODE, #1
    MOV VIEW_CNT, #2 ; 显示约1秒(0.5s*2)
K2_BEEP:
    LCALL BEEP_SHORT
    JNB K2, $        ; 等待释放
    RET
KEY_RET3:
    RET
KEY_SCAN3:
    ; 检测K3
    JNB K3, K3_PRESSED
    RET
K3_PRESSED:
    LCALL KEY_DELAY
    JB K3, KEY_RET3
    
    ; 根据模式选择功能
    MOV A, MODE
    JZ K3_NORMAL        ; 正常模式
    
    ; 设置模式：减1
    LCALL SET_DEC
    ; 更新显示
    MOV A, #0C6H        ; 温度显示位置
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP K3_BEEP
K3_NORMAL:
    ; 正常模式：查看下限
    MOV VIEW_MODE, #2
    MOV VIEW_CNT, #2 ; 显示约1秒
K3_BEEP:
    LCALL BEEP_SHORT
    JNB K3, $        ; 等待释放
    RET


KEY_RET4:
    RET
KEY_SCAN4:
    ; 检测K4
    JNB K4, K4_PRESSED
    RET
K4_PRESSED:
    LCALL KEY_DELAY
    JB K4, KEY_RET4
    
    ; 根据模式选择功能
    MOV A, MODE
    JZ K4_NORMAL        ; 正常模式
    
    ; 设置模式：切换正负
    MOV A, SET_SIGN
    CPL A
    MOV SET_SIGN, A
    ; 更新符号
    LCALL SET_UPDATE_SIGN
    ; 更新显示
    MOV A, #0C6H        ; 温度显示位置
    LCALL LCD_CMD
    MOV TEMP_H, SET_TEMP_H
    MOV TEMP_L, SET_TEMP_L
    MOV SIGN, SET_SIGN
    LCALL CONVERT_TEMP
    LCALL DISPLAY_TEMP
    SJMP K4_BEEP
K4_NORMAL:
    ; 正常模式：切换按键音
    MOV A, BEEP_FLAG
    CPL A
    MOV BEEP_FLAG, A
K4_BEEP:
    LCALL BEEP_SHORT  ; 总是调用，内部会检查标志
    JNB K4, $        ; 等待释放
    RET              ; 关键：添加返回指令
; 按键防抖延时
KEY_DELAY:
    MOV R5, #10
    DJNZ R5, $
    RET

; 短蜂鸣音
BEEP_SHORT:
    MOV A, BEEP_FLAG
    JZ NO_BEEP
    
    ; 产生短促的"滴"声
    SETB BEEP
    ; 足够长的延时 (约5ms)
    MOV R6, #10

BEEP_DELAY1:
    MOV R7, #250
    DJNZ R7, $
    DJNZ R6, BEEP_DELAY1
    CLR BEEP      ; 确保发声后关闭

NO_BEEP:
    RET

;===== 设置模式加减功能 =====;
SET_INC:
    ; 设置值加1 (整数部分)
    MOV A, SET_SIGN
    JNZ SET_INC_NEG
    ; 正数加1
    MOV A, SET_TEMP_L
    ADD A, #16      ; 加1°C (16个最小单位)
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    ADDC A, #0
    MOV SET_TEMP_H, A
    ; 检查上限(125°C)
    MOV A, SET_TEMP_H
    JNZ SET_INC_CHECK
    MOV A, SET_TEMP_L
    CJNE A, #0D0H, SET_INC_CHECK  ; 125*16=2000(07D0H)
    JC SET_INC_CHECK
    ; 超过上限
    MOV SET_TEMP_L, #0D0H  ; 125°C
    MOV SET_TEMP_H, #07H
    SJMP SET_INC_END

SET_INC_CHECK:
    ; 检查是否从负变正
    MOV A, SET_TEMP_H
    ANL A, #80H
    JZ SET_INC_END   ; 仍是正数
    ; 符号变化(负变正)
    MOV SET_SIGN, #0
    SJMP SET_INC_END

SET_INC_NEG:
    ; 负数加1(绝对值减小)
    MOV A, SET_TEMP_L
    ADD A, #16
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    ADDC A, #0
    MOV SET_TEMP_H, A
    ; 检查是否变为正数
    MOV A, SET_TEMP_H
    ANL A, #80H
    JNZ SET_INC_END
    ; 符号变化(负变正)
    MOV SET_SIGN, #0

SET_INC_END:
    RET

SET_DEC:
    ; 设置值减1 (整数部分)
    MOV A, SET_SIGN
    JZ SET_DEC_POS
    ; 负数减1(绝对值增加)
    MOV A, SET_TEMP_L
    CLR C
    SUBB A, #16
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    SUBB A, #0
    MOV SET_TEMP_H, A
    ; 检查下限(-55°C)
    MOV A, SET_TEMP_H
    CJNE A, #0FFH, SET_DEC_CHECK
    MOV A, SET_TEMP_L
    CJNE A, #0B0H, SET_DEC_CHECK  ; -55*16=-880(FC90H)
    JNC SET_DEC_CHECK
    ; 低于下限
    MOV SET_TEMP_L, #90H  ; -55°C
    MOV SET_TEMP_H, #0FCH
    RET

SET_DEC_CHECK:
    ; 检查是否从正变负
    MOV A, SET_TEMP_H
    ANL A, #80H
    JNZ SET_DEC_END   ; 仍是负数
    ; 符号变化(正变负)
    MOV SET_SIGN, #1
    SJMP SET_DEC_END

SET_DEC_POS:
    ; 正数减1
    MOV A, SET_TEMP_L
    CLR C
    SUBB A, #16
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    SUBB A, #0
    MOV SET_TEMP_H, A
    ; 检查是否变为负数
    MOV A, SET_TEMP_H
    ANL A, #80H
    JZ SET_DEC_END
    ; 符号变化(正变负)
    MOV SET_SIGN, #1

SET_DEC_END:
    RET

; 更新设置模式下的符号
;===== 修复后的符号更新子程序 =====;
SET_UPDATE_SIGN:
    MOV A, SET_SIGN
    JNZ SET_POSITIVE
    
    ; 正转负：取补码 (移除多余的ORL)
    MOV A, SET_TEMP_L
    CPL A
    ADD A, #1
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    CPL A
    ADDC A, #0
    MOV SET_TEMP_H, A    ; 注意：这里移除了 ORL A,#80H
    RET

SET_POSITIVE:
    ; 负转正：取补码 (移除多余的ANL)
    MOV A, SET_TEMP_L
    CPL A
    ADD A, #1
    MOV SET_TEMP_L, A
    MOV A, SET_TEMP_H
    CPL A
    ADDC A, #0
    MOV SET_TEMP_H, A    ; 注意：这里移除了 ANL A,#7FH
    RET

;===== 报警检查子程序 =====;
CHECK_ALARM:
    ; 保存当前温度的原始值用于比较
    MOV A, RAW_TEMP_H
    MOV R2, A
    MOV A, RAW_TEMP_L
    MOV R3, A
    
    ; 比较上限和下限以确定模式
    CLR C
    MOV A, TEMP_HIGH_H
    SUBB A, TEMP_LOW_H
    JNZ CHECK_MODE
    MOV A, TEMP_HIGH_L
    SUBB A, TEMP_LOW_L
CHECK_MODE:
    JC REVERSE_MODE    ; 如果上限<下限，跳转到反向模式
    
    ; 正常模式 (上限>下限)
    ; 先检查是否低于下限
    CLR C
    MOV A, R3          ; 当前温度低字节
    SUBB A, TEMP_LOW_L
    MOV A, R2          ; 当前温度高字节
    SUBB A, TEMP_LOW_H
    JC ALARM_ON        ; 如果当前温度 < 下限，报警
    
    ; 再检查是否高于上限
    CLR C
    MOV A, TEMP_HIGH_L
    SUBB A, R3         ; 当前温度低字节
    MOV A, TEMP_HIGH_H
    SUBB A, R2         ; 当前温度高字节
    JC ALARM_ON        ; 如果当前温度 > 上限，报警
    SJMP ALARM_OFF     ; 在范围内，关闭报警
    
REVERSE_MODE:
    ; 反向模式 (下限>上限)
    ; 检查是否在报警区间内 (上限 < 当前温度 < 下限)
    
    ; 先检查是否高于上限
    CLR C
    MOV A, TEMP_HIGH_L
    SUBB A, R3         ; 当前温度低字节
    MOV A, TEMP_HIGH_H
    SUBB A, R2         ; 当前温度高字节
    JNC ALARM_OFF      ; 如果当前温度 <= 上限，不报警
    
    ; 再检查是否低于下限
    CLR C
    MOV A, R3          ; 当前温度低字节
    SUBB A, TEMP_LOW_L
    MOV A, R2          ; 当前温度高字节
    SUBB A, TEMP_LOW_H
    JNC ALARM_OFF      ; 如果当前温度 >= 下限，不报警
    
ALARM_ON:
    SETB ALARM         ; 开启报警输出
    RET

ALARM_OFF:
    CLR ALARM          ; 关闭报警输出
    RET


;===== LCD驱动子程序 =====; 
; LCD初始化
LCD_INIT:
    MOV A, #38H      ; 8位模式, 2行, 5x7点阵
    LCALL LCD_CMD
    MOV A, #0CH      ; 显示开, 光标关, 闪烁关
    LCALL LCD_CMD
    MOV A, #06H      ; 地址递增, 不移屏
    LCALL LCD_CMD
    RET

; 发送命令到LCD
LCD_CMD:
    CLR RS           ; 命令模式
    CLR RW           ; 写操作
    MOV LCD_DAT, A   ; 发送命令
    SETB EN          ; 使能脉冲
    CLR EN
    LCALL DELAY_2MS  ; 延时等待
    RET

; 发送数据到LCD
LCD_DATA:
    SETB RS          ; 数据模式
    CLR RW           ; 写操作
    MOV LCD_DAT, A   ; 发送数据
    SETB EN          ; 使能脉冲
    CLR EN
    LCALL DELAY_2MS  ; 延时等待
    RET

; 清屏
LCD_CLEAR:
    MOV A, #01H      ; 清屏命令
    LCALL LCD_CMD
    RET

; 显示字符串(DPTR指向字符串)
LCD_WRITE_STRING:
    CLR A
    MOVC A, @A+DPTR  ; 取字符
    JZ WS_END        ; 遇到0结束
    LCALL LCD_DATA   ; 显示字符
    INC DPTR         ; 指向下一个
    SJMP LCD_WRITE_STRING
WS_END:
    RET

;===== DS18B20驱动子程序 =====;
; 初始化DS18B20
DS18B20_INIT:
    CLR DQ           ; 拉低总线
    MOV R6, #250     ; 延时480us (12MHz)
    DJNZ R6, $
    SETB DQ          ; 释放总线
    MOV R6, #30      ; 延时60us
    DJNZ R6, $
    
    ; 检测应答信号
    JB DQ, INIT_FAIL ; 无应答
    MOV R6, #240     ; 等待存在脉冲结束
    DJNZ R6, $
    SETB DQ          ; 释放总线
    CLR C            ; 成功标志
    RET
    
INIT_FAIL:
    SETB DQ          ; 释放总线
    SETB C            ; 失败标志
    RET

; 写一个字节到DS18B20 (A中为数据)
DS18B20_WRITE:
    MOV R7, #8       ; 8位数据
WRITE_BIT:
    CLR DQ           ; 开始写时隙
    MOV R6, #4       ; 延时8us
    DJNZ R6, $
    RRC A            ; 移出最低位
    MOV DQ, C        ; 发送位
    MOV R6, #24      ; 延时48us
    DJNZ R6, $
    SETB DQ          ; 释放总线
    DJNZ R7, WRITE_BIT
    SETB DQ          ; 释放总线
    RET

; 从DS18B20读取一个字节 (结果在A)
DS18B20_READ:
    MOV R7, #8       ; 8位数据
READ_BIT:
    CLR DQ           ; 开始读时隙
    MOV R6, #2       ; 延时4us
    DJNZ R6, $
    SETB DQ          ; 释放总线
    MOV R6, #4       ; 延时8us
    DJNZ R6, $
    MOV C, DQ        ; 读取位
    RRC A            ; 存入A
    MOV R6, #24      ; 延时48us
    DJNZ R6, $
    DJNZ R7, READ_BIT
    RET

; 读取温度值
DS18B20_READ_TEMP:
    LCALL DS18B20_INIT ; 初始化
    ;JC READ_FAIL      ; 失败处理
    
    MOV A, #0CCH      ; 跳过ROM命令
    LCALL DS18B20_WRITE
    MOV A, #44H       ; 开始温度转换
    LCALL DS18B20_WRITE
    
    ; 等待转换完成 (750ms)
    MOV R0, #150
WAIT_CONV:
    LCALL DELAY_5MS
    DJNZ R0, WAIT_CONV
    
    LCALL DS18B20_INIT ; 重新初始化
    JC READ_FAILEND
    
    MOV A, #0CCH      ; 跳过ROM
    LCALL DS18B20_WRITE
    MOV A, #0BEH      ; 读暂存器命令
    LCALL DS18B20_WRITE
    
    LCALL DS18B20_READ ; 读温度低字节
    MOV TEMP_L, A
    MOV RAW_TEMP_L, A  ; 保存原始补码
    LCALL DS18B20_READ ; 读温度高字节
    MOV TEMP_H, A
    MOV RAW_TEMP_H, A  ; 保存原始补码
    CLR C
    RET

READ_FAILEND:
    SETB C            ; 设置错误标志
    RET

;===== 温度处理子程序 =====;
; 转换温度值为数字
CONVERT_TEMP:
    MOV A, TEMP_H
    ANL A, #80H
    JZ POSITIVE
    
    ; 负温度处理（补码转原码）
    MOV SIGN, #1
    MOV A, TEMP_L
    CPL A
    ADD A, #1
    MOV TEMP_L, A
    MOV A, TEMP_H
    CPL A
    ADDC A, #0
    ANL A, #7FH       ; 清除符号位
    MOV TEMP_H, A
    SJMP CONV_CONT
    
POSITIVE:
    MOV SIGN, #0
    ; 确保正温度高位无符号扩展
    MOV A, TEMP_H
    ANL A, #0FH
    MOV TEMP_H, A
    
CONV_CONT:
    ; 提取整数部分
    MOV A, TEMP_H
    ANL A, #0FH       ; 取有效低4位
    MOV B, #16        ; 左移4位 (×16)
    MUL AB
    MOV R0, A         ; 暂存结果
    
    MOV A, TEMP_L
    SWAP A            ; 交换高低4位
    ANL A, #0FH       ; 取高4位
    ADD A, R0         ; 组合成完整整数
    MOV R1, A         ; 保存整数部分到R1
    
    ; 计算百位、十位、个位
    MOV B, #100
    DIV AB            ; A=百位, B=余数
    MOV DIGIT0, A     ; 存储百位
    
    MOV A, B          ; 余数(0-99)
    MOV B, #10
    DIV AB            ; A=十位, B=个位
    MOV DIGIT1, A
    MOV DIGIT2, B
    
    ; 小数部分处理
    MOV A, TEMP_L
    ANL A, #0FH       ; 取低4位 (小数部分)
    MOV B, #6         ; 0.0625 × 100 ≈ 6
    MUL AB
    MOV A, B          ; 取整数部分 (0-9)
    MOV DIGIT3, A
    
    RET

; 显示温度
DISPLAY_TEMP:
    ; 显示符号
    MOV A, SIGN
    JZ DISP_POS
    MOV A, #'-'       ; 负号
    LCALL LCD_DATA
    SJMP DISP_DIGITS
    
DISP_POS:
    MOV A, #' '       ; 空格
    LCALL LCD_DATA
    
DISP_DIGITS:
    ; 显示百位（如果不为0）
    MOV A, DIGIT0
    JZ NO_HUNDRED     ; 如果百位为0则不显示
    ADD A, #30H       ; 转换为ASCII
    LCALL LCD_DATA
    SJMP DISP_TENS
    
NO_HUNDRED:
    ; 百位为0时显示空格
    MOV A, #' '
    LCALL LCD_DATA

DISP_TENS:
    ; 显示十位
    MOV A, DIGIT1
    ADD A, #30H
    LCALL LCD_DATA
    
    ; 显示个位
    MOV A, DIGIT2
    ADD A, #30H
    LCALL LCD_DATA
    
    ; 显示小数点
    MOV A, #'.'
    LCALL LCD_DATA
    
    ; 显示小数位
    MOV A, DIGIT3
    ADD A, #30H
    LCALL LCD_DATA
    
    ; 显示单位
    MOV DPTR, #TEXT_DEG
    LCALL LCD_WRITE_STRING
    
    RET

;===== 延时子程序 =====;
; 0.8ms延时
DELAY_2MS:
    MOV R3, #10
DL1: MOV R4, #80
    DJNZ R4, $
    DJNZ R3, DL1
    RET

; 1ms延时
DELAY_5MS:
    MOV R5, #5
DL2: LCALL DELAY_2MS
    DJNZ R5, DL2
    RET
END