#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "coprocessador.h"

#define EXPECTED_IMG_WIDTH 160
#define EXPECTED_IMG_HEIGHT 120
#define EXPECTED_IMG_SIZE (EXPECTED_IMG_WIDTH * EXPECTED_IMG_HEIGHT)

// ========================================================================
// Códigos de Operação (apenas para o menu interativo)
// ========================================================================
#define OP_BYPASS           0
#define OP_AVERAGE_0_5X    1
#define OP_AVERAGE_0_25X   2
#define OP_NEAREST_2X      3
#define OP_NEAREST_4X      4
#define OP_NEAREST_0_5X    5
#define OP_NEAREST_0_25X   6
#define OP_REPLICATE_2X    7
#define OP_REPLICATE_4X    8

int main(int argc, char **argv)
{
    // --- Verificação de Argumentos ---
    if (argc != 2) {
        fprintf(stderr, "Uso: %s <caminho_para_imagem_160x120_grayscale.bin>\n", argv[0]);
        return 1;
    }
    
    char *image_filename = argv[1];
    unsigned char *hps_img_buffer = NULL;
    FILE *img_file = NULL;

    // --- Passo 1: Ler Arquivo de Imagem ---
    printf("Abrindo arquivo de imagem '%s'...\n", image_filename);
    img_file = fopen(image_filename, "rb");
    if (img_file == NULL) {
        perror("ERRO ao abrir arquivo");
        return 1;
    }

    hps_img_buffer = (unsigned char *)malloc(EXPECTED_IMG_SIZE);
    if (hps_img_buffer == NULL) {
        perror("ERRO ao alocar buffer para imagem");
        fclose(img_file);
        return 1;
    }

    printf("Lendo %d bytes do arquivo...\n", EXPECTED_IMG_SIZE);
    size_t bytes_read = fread(hps_img_buffer, 1, EXPECTED_IMG_SIZE, img_file);
    fclose(img_file);

    if (bytes_read != EXPECTED_IMG_SIZE) {
        fprintf(stderr, "ERRO: Tamanho incorreto. Esperado %d bytes, lido %zu bytes.\n", 
                EXPECTED_IMG_SIZE, bytes_read);
        free(hps_img_buffer);
        return 1;
    }
    printf("Arquivo lido com sucesso!\n");

    // ========================================================================
    // USANDO A API ASSEMBLY DO COPROCESSADOR
    // ========================================================================
    
    // --- Passo 2: Inicializar Coprocessador (mapeia memória) ---
    printf("\nInicializando coprocessador...\n");
    iniciar_coprocessador();
    printf("Coprocessador inicializado!\n");

    // --- Passo 3: Carregar Imagem na Memória da FPGA ---
    printf("\nCarregando imagem na FPGA...\n");
    carregar_imagem(hps_img_buffer, EXPECTED_IMG_SIZE);
    printf("Imagem carregada com sucesso!\n");

    // --- Passo 4: Processar imagem inicial (1X - sem zoom) ---
    printf("\nProcessando imagem inicial (SEM ZOOM 1X)...\n");
    api_bypass();
    printf("Processamento concluido!\n");

    // --- Passo 5: Menu Interativo ---
    int opcao = 0;
    char input_buffer[100];

    while (1) {
        printf("\n=== MENU DE OPERACOES ===\n\n");
        printf("0  - SEM ZOOM 1X\n");
        printf("1 - MEDIA 0.5X\n");
        printf("2 - MEDIA 0.25X\n");
        printf("3 - VIZINHO 2X\n");
        printf("4 - VIZINHO 4X\n");
        printf("5 - VIZINHO 0.5X\n");
        printf("6 - VIZINHO 0.25X\n");
        printf("7 - REPLICACAO 2X\n");
        printf("8 - REPLICACAO 4X\n\n");
        printf("q  - Sair\n\n");
        printf("Escolha uma opcao: ");

        // Lê entrada do usuário
        if (fgets(input_buffer, sizeof(input_buffer), stdin) == NULL) {
            printf("\nErro ao ler entrada. Saindo.\n");
            break;
        }

        // Remove espaços e nova linha
        int i = 0, j = 0;
        while (input_buffer[i] == ' ' || input_buffer[i] == '\t') {
            i++;
        }
        while (input_buffer[i] != '\0' && input_buffer[i] != '\n') {
            input_buffer[j++] = input_buffer[i++];
        }
        input_buffer[j] = '\0';

        // Verifica se quer sair
        if (strcmp(input_buffer, "q") == 0 || strcmp(input_buffer, "Q") == 0) {
            printf("Saindo...\n");
            break;
        }

        // Converte para número
        char *endptr;
        opcao = strtol(input_buffer, &endptr, 10);

        if (endptr == input_buffer || *endptr != '\0') {
            printf("ERRO: Entrada invalida. Digite um numero ou 'q'.\n");
            continue;
        }

        if (opcao < 0 || opcao > 1023) {
            printf("ERRO: Valor fora do range (0-1023).\n");
            continue;
        }

        // ========================================================================
        // Switch que chama as funções da API Assembly
        // ========================================================================
        printf("\nProcessando imagem com operacao %d...\n", opcao);
        
        switch (opcao) {
            case OP_BYPASS:
                printf("Executando: Bypass (1X - sem zoom)\n");
                api_bypass();
                break;
                
            case OP_AVERAGE_0_5X:
                printf("Executando: Reducao por media (0.5X)\n");
                api_media_0_5x();
                break;
                
            case OP_AVERAGE_0_25X:
                printf("Executando: Reducao por media (0.25X)\n");
                api_media_0_25x();
                break;
                
            case OP_NEAREST_2X:
                printf("Executando: Ampliacao por vizinho mais proximo (2X)\n");
                api_vizinho_2x();
                break;
                
            case OP_NEAREST_4X:
                printf("Executando: Ampliacao por vizinho mais proximo (4X)\n");
                api_vizinho_4x();
                break;
                
            case OP_NEAREST_0_5X:
                printf("Executando: Reducao por vizinho mais proximo (0.5X)\n");
                api_vizinho_0_5x();
                break;
                
            case OP_NEAREST_0_25X:
                printf("Executando: Reducao por vizinho mais proximo (0.25X)\n");
                api_vizinho_0_25x();
                break;
                
            case OP_REPLICATE_2X:
                printf("Executando: Ampliacao por replicacao (2X)\n");
                api_replicacao_2x();
                break;
                
            case OP_REPLICATE_4X:
                printf("Executando: Ampliacao por replicacao (4X)\n");
                api_replicacao_4x();
                break;
                
            default:
                printf("AVISO: Operacao %d nao reconhecida pela API.\n", opcao);
                break;
        }
        
        printf("Processamento concluido!\n");
    }

    // --- Passo 6: Finalizar ---
    printf("\nEncerrando coprocessador...\n");
    limpar_imagem();
    encerrar_coprocessador();
    
    // Liberar buffer
    free(hps_img_buffer);
    
    printf("\n=== Programa concluido com sucesso! ===\n");
    return 0;
}