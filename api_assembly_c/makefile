# Nome do executável final
EXEC = exec

# Arquivos-fonte
C_SRC = main.c
ASM_SRC = coprecessador.s

# Compilador e flags
CC = gcc
CFLAGS = -Wall

# Alvo padrão
all: $(EXEC)

# Regra de compilação
# $(EXEC): $(C_SRC) $(ASM_SRC)
exec : main.c coprecessador.s
	@echo "Compilando $(EXEC)..."
	gcc -o exec main.c coprecessador.s
	@echo "Compilação concluída!"

# Regra para executar o programa
run: $(EXEC)
	@echo "Executando $(EXEC) com saida_cinza.bin..."
	sudo ./$(EXEC) saida_cinza.bin
	@echo "Execução finalizada."

# Limpeza dos arquivos gerados
clean:
	@echo "Limpando arquivos..."
	rm -f $(EXEC)
	@echo "Diretório limpo!"
