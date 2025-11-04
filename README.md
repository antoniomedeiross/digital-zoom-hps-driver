# 🚀 HPS Driver para Coprocessador de Zoom em FPGA (DE1-SoC)
## Etapas 2 e 3: API em Assembly e Aplicação em C

Este repositório contém as etapas 2 e 3 de um projeto de Sistemas Digitais, focado na criação de um driver de software para um coprocessador de redimensionamento de imagens (zoom in/out) implementado em uma FPGA (DE1-SoC).

O foco principal é a **interface hardware-software** (HPS-FPGA), a criação de uma **API em Assembly (ARMv7-A)** para controle, e uma **aplicação em C** (rodando em Linux embarcado) para orquestrar as operações.

### 🔗 Repositório da Etapa 1 (Hardware-Only)
O coprocessador em Verilog (Etapa 1), que é controlado por este software, pode ser encontrado no repositório:
* **[Digital Zoom: Image Resizing with FPGA in Verilog (DE1-SoC)](https://github.com/antoniomedeiross/image_processing_fpga)**

---

## 🎯 Funcionalidades
* **Aplicação em C:** Fornece uma interface de usuário interativa (via terminal/SSH) para controlar a FPGA.
* **API em Assembly:** Expõe uma "ISA" de hardware simples para o C, abstraindo o acesso direto à memória.
* **Carregamento Dinâmico de Imagem:** Transfere uma imagem `.bin` (160x120, 8-bit grayscale) do HPS para a memória On-Chip (RAM) da FPGA.
* **Controle do Coprocessador:** Envia comandos para a FPGA para:
    * Selecionar o algoritmo de redimensionamento (Média, Vizinho Mais Próximo, Replicação).
    * Definir o fator de zoom (ex: 2x, 4x, 0.5x).
    * Disparar o início do processamento (via pulso de reset/trigger).
* **Visualização:** A imagem processada pela FPGA é exibida em tempo real em um monitor VGA.

---

## ⚙️ Arquitetura da Interface Hardware-Software

A comunicação entre o processador ARM (HPS) e a lógica da FPGA (Coprocessador) é feita via **Memória Mapeada (MMIO)** através da ponte AXI Leve (Lightweight HPS-to-FPGA Bridge).

O fluxo de controle é o seguinte:

**`[App C (Usuário)]`** -> **`[API Assembly (Driver)]`** -> **`[Ponte AXI (MMIO)]`** -> **`[Periféricos FPGA]`**

1.  **Aplicação em C (`main.c`):**
    * Roda no Linux embarcado no HPS.
    * Lida com a interface do usuário (menu, `scanf`).
    * Gerencia a memória (lê arquivo `.bin` para a DDR3, usa `mmap` para acessar a ponte).
    * Chama as funções da API Assembly (ex: `api_set_config(...)`).
2.  **API Assembly (`api_isa.s`):**
    * Define a "ISA" do coprocessador.
    * Recebe ponteiros e valores do C.
    * Executa as instruções ARM (`str`, `ldr`, `dmb`) para escrever/ler diretamente nos endereços físicos dos periféricos na FPGA.
3.  **Periféricos FPGA (no Qsys):**
    * **`onchip_memory2_1` (RAM Dual-Port):** Armazena a imagem fonte (160x120). É escrita pelo HPS (via `api_load_image`) e lida pela ALU.
    * **`pio_10bits` (PIO Output):** Recebe o valor de configuração (`tipo_alg` + `fator_zoom`).
    * **`pio_reset_alu` (PIO Output):** Recebe o pulso de trigger para iniciar o processamento.
    * **`onchip_memory_framebuffer` (RAM Dual-Port):** Armazena a imagem de saída (640x480). É escrita pela ALU e lida pelo `vga_driver`.

---

## 💻 Tecnologias Utilizadas

* **Hardware:** Placa Terasic DE1-SoC (Cyclone V SoC)
* **Linguagem HDL:** Verilog
* **Linguagem de Software:** C (aplicação), Assembly ARMv7-A (driver/API)
* **Ambiente:** Intel Quartus Prime
* **Ferramentas:** Qsys (Platform Designer), `gcc` (nativo da placa), `Makefile` (otimizar a compilacao)

---

## 🛠️ Como Compilar e Executar

Este projeto é compilado e executado **diretamente no sistema Linux embarcado na DE1-SoC**.

### Requisitos
* FPGA programada com o arquivo `.sof` gerado pelo projeto Quartus.
* Placa DE1-SoC inicializada com Linux (via cartão SD).
* Acesso ao terminal da placa (via SSH ou serial).
* Compilador `gcc` instalado na placa (`sudo apt install build-essential`).
* Uma imagem de teste 160x120 8-bit grayscale, convertida para `.bin` (dados brutos).

### 1. Preparar os Arquivos
Copie os seguintes arquivos para um diretório na sua placa DE1-SoC (ex: via `scp` ou pen drive):

1.  `main_isa_calls.c` (Seu código C principal)
2.  `api_isa.s` (Sua API em Assembly)
3.  `hps_0.h` (O header gerado pelo Qsys com os offsets)
4.  `sua_imagem_160x120.bin` (Sua imagem de teste)

### 2. Compilar na Placa
No terminal da DE1-SoC, navegue até o diretório dos arquivos e execute:

```bash
# Compila o C e o Assembly juntos, linkando-os e roda o executável em seguida
make run 
