@ ========================================================================
@ API Assembly - ISA do Coprocessador de Processamento de Imagens
@ Arquitetura: Funções de alto nível que encapsulam opcodes
@ ========================================================================

.section .text
.align 4

@ Declaração de funções globais
.global iniciar_coprocessador
.type iniciar_coprocessador, %function

.global encerrar_coprocessador
.type encerrar_coprocessador, %function

.global carregar_imagem
.type carregar_imagem, %function

.global limpar_imagem
.type limpar_imagem, %function

.global processar_imagem

.global api_bypass
.type api_bypass, %function

.global api_media_0_5x
.type api_media_0_5x, %function

.global api_media_0_25x
.type api_media_0_25x, %function

.global api_vizinho_2x
.type api_vizinho_2x, %function

.global api_vizinho_4x
.type api_vizinho_4x, %function

.global api_vizinho_0_5x
.type api_vizinho_0_5x, %function

.global api_vizinho_0_25x
.type api_vizinho_0_25x, %function

.global api_replicacao_2x
.type api_replicacao_2x, %function

.global api_replicacao_4x
.type api_replicacao_4x, %function




@ ========================================================================
@ void iniciar_coprocessador(void)
@ Mapeia a memória da ponte Lightweight HPS-FPGA
@ ========================================================================


iniciar_coprocessador:
        SUB     SP, SP, #28
        STR     R0, [SP, #0]
        STR     R1, [SP, #4]
        STR     R2, [SP, #8]
        STR     R3, [SP, #12]
        STR     R4, [SP, #16]
        STR     R5, [SP, #20]
        STR     R7, [SP, #24]

        @ Abrindo /dev/mem
        LDR     R0, =DEV_MEM
        MOV     R1, #2              @ O_RDWR
        MOV     R2, #0
        MOV     R7, #5              @ sys_open
        SVC     0

        @ Salva file descriptor
        MOV     R4, R0
        LDR     R0, =FILE_DESCRIPTOR
        STR     R4, [R0, #0]

        @ Chamando mmap2
        MOV     R0, #0              @ addr = NULL
        LDR     R1, =LW_BRIDGE_SPAN @ length
        LDR     R1, [R1, #0]
        MOV     R2, #3              @ PROT_READ | PROT_WRITE
        MOV     R3, #1              @ MAP_SHARED
        LDR     R5, =LW_BRIDGE_BASE @ offset / 4096
        LDR     R5, [R5, #0]
        LSR     R5, R5, #12         @ Divide por 4096 para mmap2
        MOV     R7, #192            @ sys_mmap2
        SVC     0

        @ Salva endereço virtual
        LDR     R1, =FPGA_VIRTUAL_ADDR
        STR     R0, [R1, #0]

        LDR     R0, [SP, #0]
        LDR     R1, [SP, #4]
        LDR     R2, [SP, #8]
        LDR     R3, [SP, #12]
        LDR     R4, [SP, #16]
        LDR     R5, [SP, #20]
        LDR     R7, [SP, #24]
        ADD     SP, SP, #28

        BX      LR

@ ========================================================================
@ void encerrar_coprocessador(void)
@ Libera o mapeamento de memória
@ ========================================================================


encerrar_coprocessador:
        SUB     SP, SP, #12
        STR     R0, [SP, #0]
        STR     R1, [SP, #4]
        STR     R7, [SP, #8]

        @ Chamando munmap
        LDR     R0, =FPGA_VIRTUAL_ADDR
        LDR     R0, [R0, #0]
        LDR     R1, =LW_BRIDGE_SPAN
        LDR     R1, [R1, #0]
        MOV     R7, #91             @ sys_munmap
        SVC     0

        @ Fechar /dev/mem
        LDR     R0, =FILE_DESCRIPTOR
        LDR     R0, [R0, #0]
        MOV     R7, #6              @ sys_close
        SVC     0

        LDR     R0, [SP, #0]
        LDR     R1, [SP, #4]
        LDR     R7, [SP, #8]
        ADD     SP, SP, #12

        BX      LR

@ ========================================================================
@ void carregar_imagem(unsigned char *buffer_hps, int tamanho)
@ Transfere imagem do buffer HPS para memória FPGA
@ R0 = ponteiro para buffer na memória HPS
@ R1 = tamanho da imagem em bytes
@ ========================================================================


carregar_imagem:
        PUSH    {R4-R7, LR}
        
        @ R4 = origem (memória HPS) endereço
        @ R5 = destino (memória FPGA) endereço
        @ R6 = contador de bytes a copiar
        MOV     R4, R0 
        MOV     R6, R1      @19200
        
        @ Calcula endereço destino: virtual_base + IMAGE_MEM_OFFSET
        LDR     R5, =FPGA_VIRTUAL_ADDR
        LDR     R5, [R5, #0]
        LDR     R7, =IMAGE_MEM_OFFSET
        LDR     R7, [R7, #0]
        ADD     R5, R5, R7          @ endereço destino

        @ Verifica alinhamento para otimização
        ORR     R7, R4, R5          @ Combina ambos os endereços
        TST     R7, #3              @ Verifica se ambos os endereços são múltiplos de 4
        BNE     transfer_byte       @ Se não alinhado, copia byte a byte

        @ Copia em blocos de 4 bytes (words)
        LSR     R7, R6, #2          @ Número de words
        CMP     R7, #0              @ Verifica se há words para copiar
        BEQ     transfer_remaining  

transfer_word_loop:
        LDR     R3, [R4], #4    @ lê 4 bytes do hps; #4 incrementa sozinho
        STR     R3, [R5], #4    @ escreve 4 bytes na FPGA
        SUBS    R7, R7, #1      @ decrementa contador de words
        BNE     transfer_word_loop

transfer_remaining:
        AND     R6, R6, #3          @ Bytes restantes
        CMP     R6, #0
        BEQ     transfer_done

transfer_byte:
        LDRB    R3, [R4], #1        @ lê 1 byte do hps
        STRB    R3, [R5], #1        @ escreve 1 byte na FPGA
        SUBS    R6, R6, #1
        BNE     transfer_byte

transfer_done:
        DSB                         @ Garante conclusão das escritas(Data Synchronization Barrier)
        POP     {R4-R7, PC}         @ Retorna 

@ ========================================================================
@ void limpar_imagem(void)
@ Limpa (zera) toda a memória de imagem
@ ========================================================================

limpar_imagem:
        PUSH    {R4-R7} 
        
        @ Endereço base
        LDR     R4, =FPGA_VIRTUAL_ADDR
        LDR     R4, [R4, #0]
        LDR     R5, =IMAGE_MEM_OFFSET
        LDR     R5, [R5, #0]
        ADD     R4, R4, R5          @ Endereço base da memória de imagem
        
        @ Tamanho
        LDR     R6, =IMAGE_SIZE     @ Tamanho da imagem em bytes
        LDR     R6, [R6, #0]       
        
        MOV     R7, #0              @ Valor para preencher
        
        @ Limpa em words
        LSR     R5, R6, #2          @ Número de words
        CMP     R5, #0              @ Verifica se há words para limpar
        BEQ     clear_remaining_bytes

clear_word_loop:
        STR     R7, [R4], #4
        SUBS    R5, R5, #1
        BNE     clear_word_loop

clear_remaining_bytes:
        AND     R6, R6, #3          @ Bytes restantes
        CMP     R6, #0              @ Verifica se há bytes restantes
        BEQ     clear_done 

clear_byte_loop:
        STRB    R7, [R4], #1        @ Zera byte a byte
        SUBS    R6, R6, #1          @ Decrementa contador de bytes
        BNE     clear_byte_loop

clear_done:
        DSB                        @ Garante conclusão das escritas
        POP     {R4-R7}            @ Restora registradores
        BX      LR                 @ Retorna




@ ========================================================================
@ FUNÇÕES AUXILIARES INTERNAS
@ ========================================================================

@ void escrever_config(int valor_config)
@ Função interna - escreve configuração no PIO de 10 bits
escrever_config:
        PUSH    {R4-R5, LR}
        
        @ Mascara para 10 bits
        LDR     R4, =0x3FF         @ 1111111111
        AND     R0, R0, R4         @ Aplica máscara
        
        @ Endereço do PIO: virtual_base + CONFIG_PIO_OFFSET
        LDR     R4, =FPGA_VIRTUAL_ADDR
        LDR     R4, [R4, #0]
        LDR     R5, =CONFIG_PIO_OFFSET
        LDR     R5, [R5, #0]
        ADD     R4, R4, R5          @ Endereço do PIO
        
        @ Escreve no PIO
        STR     R0, [R4, #0]        @ Escreve valor
        DSB                         @ Data Synchronization Barrier
        
        POP     {R4-R5, PC}         @ Retorna
        

@ void enviar_start(void)
@ Função interna - envia pulso de start
enviar_start:
        PUSH    {R4-R5, LR} 
        
        @ Endereço do PIO Reset: virtual_base + RESET_PIO_OFFSET
        LDR     R4, =FPGA_VIRTUAL_ADDR
        LDR     R4, [R4, #0]
        LDR     R5, =RESET_PIO_OFFSET
        LDR     R5, [R5, #0]
        ADD     R4, R4, R5          @ Endereço do PIO Reset

        @ Pulso alto
        MOV     R0, #1              @ Valor alto
        STR     R0, [R4, #0]        @ Escreve valor
        DSB                         @ Data Synchronization Barrier
        
        @ Delay (~1us)
        MOV     R5, #50             @ contador de delay
delay_start:
        SUBS    R5, R5, #1          @ decrementa
        BNE     delay_start         @ repete até zero
        
        @ Pulso baixo
        MOV     R0, #0              @ Valor baixo
        STR     R0, [R4, #0]        @ Escreve valor
        DSB                         @ Data Synchronization Barrier
        
        POP     {R4-R5, PC}         @ Retorna



@ void processar_imagem(int operacao)
@ Função interna - processa imagem com operação especificada
@ R0 = código da operação

processar_imagem:
        PUSH    {LR}             
        
        @ Escreve configuração (operação)
        BL      escrever_config
        
        @ Envia trigger 
        BL      enviar_start
        
        POP     {PC}    



@ ========================================================================
@ FUNÇÕES DA ISA 
@ Cada função encapsula um opcode específico
@ ========================================================================

@ void api_bypass(void)
api_bypass:
        PUSH    {LR} 
        MOV     R0, #0              @ Opcode 0
        BL      processar_imagem
        POP     {PC}


@ void api_media_0_5x(void)
api_media_0_5x:
        PUSH    {LR}
        MOV     R0, #11             @ Opcode 11
        BL      processar_imagem
        POP     {PC}


@ void api_media_25x(void)
api_media_0_25x:
        PUSH    {LR}
        MOV     R0, #12             @ Opcode 12
        BL      processar_imagem
        POP     {PC}




@ void api_vizinho_2x(void)
api_vizinho_2x:
        PUSH    {LR}
        MOV     R0, #17             @ Opcode 17
        BL      processar_imagem
        POP     {PC}



@ void api_vizinho_4x(void)
api_vizinho_4x:
        PUSH    {LR}
        MOV     R0, #18             @ Opcode 18
        BL      processar_imagem
        POP     {PC}



@ void api_vizinho_0_5x(void)
api_vizinho_0_5x:
        PUSH    {LR}
        MOV     R0, #27             @ Opcode 27
        BL      processar_imagem
        POP     {PC}


@ void api_vizinho_0_25x(void)
api_vizinho_0_25x:
        PUSH    {LR}
        MOV     R0, #28             @ Opcode 28
        BL      processar_imagem
        POP     {PC}



@ void api_replicacao_2x(void)
api_replicacao_2x:
        PUSH    {LR}
        MOV     R0, #33             @ Opcode 33
        BL      processar_imagem
        POP     {PC}


@ void api_replicacao_4x(void)
api_replicacao_4x:
        PUSH    {LR}
        MOV     R0, #34             @ Opcode 34
        BL      processar_imagem
        POP     {PC}

        

@ ========================================================================
@ Seção de Dados
@ ========================================================================
.section .data
.align 4

DEV_MEM:
        .asciz "/dev/mem"

@ Endereços físicos e tamanhos
LW_BRIDGE_BASE:
        .word 0xFF200000

LW_BRIDGE_SPAN:
        .word 0x30000           @ 192KB

@ Offsets dos componentes na ponte Lightweight
IMAGE_MEM_OFFSET:
        .word 0x0000            @ Offset da memória onchip

CONFIG_PIO_OFFSET:
        .word 0x8010            @ PIO de 10 bits

RESET_PIO_OFFSET:
        .word 0x8000            @ PIO de reset

@ Dimensões da imagem
IMAGE_WIDTH:
        .word 160

IMAGE_HEIGHT:
        .word 120

IMAGE_SIZE:
        .word 19200             @ 160 x 120

@ Variáveis de controle
FPGA_VIRTUAL_ADDR:
        .space 4

FILE_DESCRIPTOR:
        .space 4

