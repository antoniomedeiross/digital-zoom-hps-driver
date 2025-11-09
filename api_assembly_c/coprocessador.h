#ifndef COPROCESSADOR_H
#define COPROCESSADOR_H

/*
 * ========================================================================
 * API do Coprocessador de Processamento de Imagens
 * Interface de alto nível - Funções implementadas em Assembly ARM
 * ========================================================================
 */

// ========================================================================
// Funções de Inicialização e Finalização
// ========================================================================

/**
 * Inicializa o coprocessador mapeando a ponte Lightweight HPS-FPGA
 * - Abre /dev/mem
 * - Mapeia memória física para espaço virtual
 * - Salva endereços dos componentes (PIOs, memória onchip)
 * 
 * chamada antes de qualquer outra operação
 */
extern void iniciar_coprocessador(void);

/**
 * Encerra o coprocessador liberando recursos
 * - Desmapeia memória
 * - Fecha /dev/mem
 * 
 * chamada ao final do programa
 */
extern void encerrar_coprocessador(void);

// ========================================================================
// Funções de Manipulação de Imagem
// ========================================================================

/**
 * Carrega imagem do buffer HPS para a memória da FPGA
 * 
 * @param buffer_hps: Ponteiro para buffer na memória DDR3 do HPS
 * @param tamanho: Tamanho da imagem em bytes 19200 
 * 
 */
extern void carregar_imagem(unsigned char *buffer_hps, int tamanho);

/**
 * Limpa (zera) toda a memória de imagem na FPGA
 * Útil para resetar antes de processar nova imagem
 */
extern void limpar_imagem(void);

// ========================================================================
// ISA do Coprocessador - Funções de Alto Nível
// Cada função encapsula uma operação específica do coprocessador
// ========================================================================

/**
 * Operação 0: BYPASS - Passa imagem sem alteração (1X)
 * Mantém a imagem original sem aplicar zoom ou redução
 */
extern void api_bypass(void);

/**
 * Operação 11: MÉDIA 0.5X - Redução para metade do tamanho
 * Usa interpolação por média de pixels vizinhos
 */
extern void api_media_0_5x(void);

/**
 * Operação 12: MÉDIA 0.25X - Redução para 1/4 do tamanho
 * Usa interpolação por média de pixels vizinhos
 */
extern void api_media_0_25x(void);

/**
 * Operação 17: VIZINHO MAIS PRÓXIMO 2X - Ampliação 2X
 * Duplica o tamanho usando interpolação por vizinho mais próximo
 */
extern void api_vizinho_2x(void);

/**
 * Operação 18: VIZINHO MAIS PRÓXIMO 4X - Ampliação 4X
 * Quadruplica o tamanho usando interpolação por vizinho mais próximo
 */
extern void api_vizinho_4x(void);

/**
 * Operação 27: VIZINHO MAIS PRÓXIMO 0.5X - Redução 0.5X
 * Reduz para metade usando interpolação por vizinho mais próximo
 */
extern void api_vizinho_0_5x(void);

/**
 * Operação 28: VIZINHO MAIS PRÓXIMO 0.25X - Redução 0.25X
 * Reduz para 1/4 usando interpolação por vizinho mais próximo
 */
extern void api_vizinho_0_25x(void);

/**
 * Operação 33: REPLICAÇÃO 2X - Ampliação 2X por replicação
 * Duplica o tamanho replicando cada pixel
 */
extern void api_replicacao_2x(void);

/**
 * Operação 34: REPLICAÇÃO 4X - Ampliação 4X por replicação
 * Quadruplica o tamanho replicando cada pixel
 */
extern void api_replicacao_4x(void);

// ========================================================================
// Nota sobre a Arquitetura
// ========================================================================
/*
 * A ISA do coprocessador está completamente encapsulada no Assembly.
 * O código C não precisa conhecer os opcodes numéricos (0, 11, 17, etc).
 * Cada função da API mapeia diretamente para uma operação do hardware.
 */

#endif // COPROCESSADOR_H