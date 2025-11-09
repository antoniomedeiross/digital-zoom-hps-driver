module alu_algoritmos ( // Sugestão: adicione '_hps' para clareza
    input wire clk,
    input wire reset,
    
    // --- Interface com o HPS ---
    input wire [9:0] control_data_in, // Recebe os dados de controle do HPS
	 // zoom_enable -> [2:0], // 00=normal, 01=zoom out 0.5x, 10=zoom in 2x
    // tipo_alg -> [6:3],    // 0000  

    input wire        start_in,        // Recebe o pulso de início do HPS
	 
    // Interface com a RAM  160x120 (síncrona)
    input wire [7:0] rom_data_in,
    output reg [14:0] rom_addr_out,
     
    // Interface com a RAM (framebuffer 640x480)
    output reg [7:0] ram_data_out,
    output reg [18:0] ram_addr_out,
    output reg ram_wren_out,
	 
    output wire [31:0] status_data_out // Envia o status para o HPS
);

	 wire [2:0] zoom_enable;
    wire [3:0] tipo_alg;
    assign zoom_enable = control_data_in[2:0];
    assign tipo_alg    = control_data_in[6:3];
	 
	 //0001
	 //011
	 //0000001011

	 reg done;
	 
	/*
     0000 -> sem nada
     0001 -> media
     0010 -> vizinho in 2x
     0011 -> vizinho out 0.5x
     0100 -> replicaçao
	*/

    // Parâmetros da imagem original
    localparam ROM_IMG_W = 160;
    localparam ROM_IMG_H = 120;
    
    // Parâmetros da RAM
    localparam RAM_WIDTH = 640;
    localparam RAM_HEIGHT = 480;
    localparam RAM_SIZE = RAM_WIDTH * RAM_HEIGHT;
     
    // parametros usados no vizinho mais proximo 
    localparam ROM_SIZE = ROM_IMG_W * ROM_IMG_H;
    localparam NO_ZOOM_OFFSET_X = 240; // (640 - 160)/2
    localparam NO_ZOOM_OFFSET_Y = 180; // (480 - 120)/2
    localparam ZOOM_OFFSET_X = 160; // (640 - 320)/2
    localparam ZOOM_OFFSET_Y = 120; // (480 - 240)/2
    localparam ZOOM4X_OFFSET_Y = 0;
    localparam ZOOM4X_OFFSET_X = 0;
	  
	 localparam ZOOM_OUT_025_OFFSET_X = 300; // (640-40)/2
    localparam ZOOM_OUT_025_OFFSET_Y = 225; // (480-30)/2

    // Offsets para centralizar as imagens
    localparam NORMAL_OFFSET_X = 240;   // (640-160)/2
    localparam NORMAL_OFFSET_Y = 180;   // (480-120)/2
    localparam ZOOM_OUT_OFFSET_X = 280; // (640-80)/2
    localparam ZOOM_OUT_OFFSET_Y = 210; // (480-60)/2
    localparam ZOOM_IN_OFFSET_X = 160;   // (640-320)/2
    localparam ZOOM_IN_OFFSET_Y = 120;   // (480-240)/2
    
    // Estados da FSM MEDIA DE BLOCOS 
    localparam S_IDLE              = 4'd0;
    localparam S_CLEAR_FRAME       = 4'd1;
    localparam S_PROCESS_PIXEL     = 4'd2;
    localparam S_FETCH_PIXEL_READ  = 4'd3; // Estado único para ler pixel no modo normal
    localparam S_WRITE_RAM         = 4'd4;
    localparam S_DONE              = 4'd5;
	 

	localparam S_FETCH_16_INIT     = 4'd11;
	localparam S_FETCH_16_SET_ADDR = 4'd12;
	localparam S_FETCH_16_READ_ADD = 4'd13;
	localparam S_WRITE_RAM_AVG     = 4'd14;
	localparam S_CALC_AVERAGE_4    = 4'd15;


    // Estados pipelined para ler o bloco 2x2 no zoom out
    localparam S_FETCH_BLOCK_00    = 4'd6;
    localparam S_FETCH_BLOCK_01    = 4'd7;
    localparam S_FETCH_BLOCK_10    = 4'd8;
    localparam S_FETCH_BLOCK_11    = 4'd9;
    localparam S_CALC_AVERAGE      = 4'd10;
	 localparam S_CLEAR_ALL = 4'd11;

    // Estados FSM VIZINHO
    localparam S_CLEAR_BORDERS   = 3'd1;
    localparam S_SET_ADDR        = 3'd2;
    localparam S_READ_ROM        = 3'd3;
     
    // Estados FSM vizinho 0.5x
    localparam S_SET_ROM_ADDR = 3'd3;
     
    // Estados FSM VIZINHO 0.5x
    localparam VZ05_IDLE = 4'd0;
    localparam VZ05_CLEAR_FRAME = 4'd1;
    localparam VZ05_PROCESS_PIXEL = 4'd2;
    localparam VZ05_SET_ROM_ADDR = 4'd3;
    localparam VZ05_READ_ROM = 4'd4;
    localparam VZ05_WRITE_RAM = 4'd5;
    localparam VZ05_DONE = 4'd6;

    // Estados específicos para replicação
    localparam REP_IDLE        = 4'd0;
    localparam REP_CLEAR       = 4'd1;
    localparam REP_PROCESS     = 4'd2;
    localparam REP_SET_ADDR    = 4'd3;
    localparam REP_READ_ROM    = 4'd4;
    localparam REP_WRITE_RAM   = 4'd5;
    localparam REP_DONE        = 4'd6;
    localparam REP_PROCESS_PIXEL = 4'd2; 
	 


     
     
    
    // Registradores para media de blocos 4x4
	reg [11:0] sum_pixels;        // 12-bit accumulator
	reg [1:0] block_x_counter;    // Counter for 4x4 block columns
	reg [1:0] block_y_counter;    // Counter for 4x4 block rows
		  
		  
    reg [3:0] state;
    reg [18:0] ram_counter;
     
    // regs vizinho prox 2x
    reg [14:0] pixel_counter;
    reg [3:0] zoom_phase;
    reg [7:0] rom_x;
    reg [6:0] rom_y;
    reg [7:0] rom_data_reg;
     
    // REGs vizinho mais prox 0.5x
    reg [7:0] src_x;
    reg [6:0] src_y;
    reg [9:0] temp_x;
    reg [8:0] temp_y;
    
    // Coordenadas atuais na RAM
    reg [9:0] current_x;
    reg [8:0] current_y;
    
    // Coordenadas de origem na ROM
    reg [7:0] src_x_base;
    reg [6:0] src_y_base;
    
    // regs replicaçao 
    reg [7:0] rep_rom_x;
    reg [6:0] rep_rom_y;
    reg [1:0] rep_phase;

    // Registradores para armazenar os 4 pixels do bloco 2x2
    reg [7:0] pixel_00, pixel_01, pixel_10, pixel_11;
     
    // Calcula coordenadas atuais da RAM
    always @(*) begin
        current_x = ram_counter % RAM_WIDTH;
        current_y = ram_counter / RAM_WIDTH;
    end
     
    always @(*) begin
        rom_x = pixel_counter % ROM_IMG_W;
        rom_y = pixel_counter / ROM_IMG_W;
    end
     
     reg [1:0] local_offset_x;
     reg [1:0] local_offset_y;
     
     always @(*) begin
    local_offset_x = zoom_phase[1:0];
    local_offset_y = zoom_phase[3:2];
end    
    
        
    
    // FSM Principal
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            ram_counter <= 0;
            done <= 1'b0;
            ram_wren_out <= 1'b0;
            rom_addr_out <= 0;
            // Zera outros registradores se necessário
        end else begin
            case(tipo_alg) 
				    4'b0000: begin
                    case (state)
                        S_IDLE: begin
                            ram_counter <= 0;
                            done <= 1'b0;
                            ram_wren_out <= 1'b0;
                            state <= S_PROCESS_PIXEL;
                        end

                        S_PROCESS_PIXEL: begin
                            if (ram_counter >= RAM_SIZE) begin
                                state <= S_DONE;
                            end else begin
                                // Verifica se o pixel atual da RAM está dentro da área da imagem centralizada
                                if (current_y >= NORMAL_OFFSET_Y && current_y < NORMAL_OFFSET_Y + ROM_IMG_H &&
                                    current_x >= NORMAL_OFFSET_X && current_x < NORMAL_OFFSET_X + ROM_IMG_W)
                                begin
                                    // Se estiver na área da imagem, calcula o endereço da ROM correspondente
                                    src_x_base <= current_x - NORMAL_OFFSET_X;
                                    src_y_base <= current_y - NORMAL_OFFSET_Y;
                                    state <= S_READ_ROM; // Próximo estado: buscar o pixel da ROM
                                end 
                                else begin
                                    // Se estiver nas bordas, escreve preto diretamente
                                    ram_wren_out <= 1'b1;
                                    ram_data_out <= 8'h00;
                                    ram_addr_out <= ram_counter;
                                    ram_counter <= ram_counter + 1;
                                    state <= S_PROCESS_PIXEL; // Continua no mesmo estado
                                end
                            end
                        end
                        
                        S_READ_ROM: begin
                            // Define o endereço da ROM e prepara para escrever na RAM no próximo ciclo
                            rom_addr_out <= src_y_base * ROM_IMG_W + src_x_base;
                            ram_wren_out <= 1'b0;
                            state <= S_WRITE_RAM;
                        end

                        S_WRITE_RAM: begin
                            // O dado da ROM está disponível em rom_data_in, escreve na RAM
                            ram_wren_out <= 1'b1;
                            ram_data_out <= rom_data_in;
                            ram_addr_out <= ram_counter;
                            ram_counter <= ram_counter + 1;
                            state <= S_PROCESS_PIXEL; // Volta para processar o próximo pixel da RAM
                        end

                        S_DONE: begin
                            done <= 1'b1;
                            ram_wren_out <= 1'b0;
                        end

                        default: state <= S_IDLE;
                    endcase
                end// nada selecionado ================================
					 
					 
                4'b0001: begin
                    //===============================================================
                    // MEDIA DE BLOCOS
                    //===============================================================
              
                    case (state)
                        S_IDLE: begin
                            ram_counter <= 0;
                            done <= 1'b0;
                            ram_wren_out <= 1'b0;
                            state <= S_CLEAR_FRAME;
                        end
                        
                        S_CLEAR_FRAME: begin
                            ram_wren_out <= 1'b1;
                            ram_data_out <= 8'h00; // Preto
                            ram_addr_out <= ram_counter;
                            
                            if (ram_counter < RAM_SIZE - 1) begin
                                ram_counter <= ram_counter + 1;
                            end else begin
                                ram_counter <= 0;
                                ram_wren_out <= 1'b0;
                                state <= S_PROCESS_PIXEL;
                            end
                        end
                        
                        S_PROCESS_PIXEL: begin
                            if (ram_counter >= RAM_SIZE) begin
                                state <= S_DONE;
                            end else begin
                                ram_wren_out <= 1'b0;
                                
                                // MODO NORMAL 1X
                                if (zoom_enable == 3'b000 &&
                                    current_y >= NORMAL_OFFSET_Y && current_y < NORMAL_OFFSET_Y + ROM_IMG_H &&
                                    current_x >= NORMAL_OFFSET_X && current_x < NORMAL_OFFSET_X + ROM_IMG_W)
                                begin
                                    src_x_base <= current_x - NORMAL_OFFSET_X;
                                    src_y_base <= current_y - NORMAL_OFFSET_Y;
                                    state <= S_FETCH_PIXEL_READ;
                                // MODO ZOOM OUT 0.5X (MÉDIA 2X2)
                                end else if (zoom_enable == 3'b011 &&
                                           current_y >= ZOOM_OUT_OFFSET_Y && current_y < ZOOM_OUT_OFFSET_Y + (ROM_IMG_H / 2) &&
                                           current_x >= ZOOM_OUT_OFFSET_X && current_x < ZOOM_OUT_OFFSET_X + (ROM_IMG_W / 2))
                                begin
                                    src_x_base <= (current_x - ZOOM_OUT_OFFSET_X) * 2;
                                    src_y_base <= (current_y - ZOOM_OUT_OFFSET_Y) * 2;
                                    state <= S_FETCH_BLOCK_00;
                                // MODO ZOOM OUT 0.25X (MÉDIA 4X4)
                                end else if (zoom_enable == 3'b100 &&
                                           current_y >= ZOOM_OUT_025_OFFSET_Y && current_y < ZOOM_OUT_025_OFFSET_Y + (ROM_IMG_H / 4) &&
                                           current_x >= ZOOM_OUT_025_OFFSET_X && current_x < ZOOM_OUT_025_OFFSET_X + (ROM_IMG_W / 4))
                                begin
                                    src_x_base <= (current_x - ZOOM_OUT_025_OFFSET_X) * 4;
                                    src_y_base <= (current_y - ZOOM_OUT_025_OFFSET_Y) * 4;
                                    state <= S_FETCH_16_INIT;
										  end else if(zoom_enable != 3'b000 && zoom_enable != 3'b011 && zoom_enable != 3'b100 && current_y >= NORMAL_OFFSET_Y && current_y < NORMAL_OFFSET_Y + ROM_IMG_H &&
                                    current_x >= NORMAL_OFFSET_X && current_x < NORMAL_OFFSET_X + ROM_IMG_W) begin
												src_x_base <= current_x - NORMAL_OFFSET_X;
                                    src_y_base <= current_y - NORMAL_OFFSET_Y;
                                    state <= S_FETCH_PIXEL_READ;
                                end else begin
                                    // Fora da área de desenho, apenas avança para o próximo pixel
                                    ram_counter <= ram_counter + 1;
                                    state <= S_PROCESS_PIXEL;
                                end
                            end
                        end

                        // --- Lógica para 1x ---
                        S_FETCH_PIXEL_READ: begin
                            rom_addr_out <= src_y_base * ROM_IMG_W + src_x_base;
                            state <= S_WRITE_RAM_AVG;
                        end

                        // --- Lógica para Média 2x2 (Zoom 0.5x) ---
                        S_FETCH_BLOCK_00: begin
                            rom_addr_out <= src_y_base * ROM_IMG_W + src_x_base;
                            state <= S_FETCH_BLOCK_01;
                        end
                        S_FETCH_BLOCK_01: begin
                            pixel_00 <= rom_data_in;
                            rom_addr_out <= src_y_base * ROM_IMG_W + (src_x_base + 1);
                            state <= S_FETCH_BLOCK_10;
                        end
                        S_FETCH_BLOCK_10: begin
                            pixel_01 <= rom_data_in;
                            rom_addr_out <= (src_y_base + 1) * ROM_IMG_W + src_x_base;
                            state <= S_FETCH_BLOCK_11;
                        end
                        S_FETCH_BLOCK_11: begin
                            pixel_10 <= rom_data_in;
                            rom_addr_out <= (src_y_base + 1) * ROM_IMG_W + (src_x_base + 1);
                            state <= S_CALC_AVERAGE_4;
                        end
                        S_CALC_AVERAGE_4: begin
                            pixel_11 <= rom_data_in;
                            state <= S_WRITE_RAM_AVG;
                        end

                        // --- Lógica para Média 4x4 (Zoom 0.25x) ---
                        S_FETCH_16_INIT: begin
                            sum_pixels      <= 12'd0;
                            block_x_counter <= 2'd0;
                            block_y_counter <= 2'd0;
                            state           <= S_FETCH_16_SET_ADDR;
                        end

                        S_FETCH_16_SET_ADDR: begin
                            rom_addr_out <= (src_y_base + block_y_counter) * ROM_IMG_W + (src_x_base + block_x_counter);
                            state        <= S_FETCH_16_READ_ADD;
                        end

                        S_FETCH_16_READ_ADD: begin
                            sum_pixels <= sum_pixels + rom_data_in; // Acumula o valor do pixel
                            if (block_x_counter == 2'd3) begin
                                block_x_counter <= 2'd0;
                                if (block_y_counter == 2'd3) begin
                                    state <= S_WRITE_RAM_AVG; // Terminou o bloco 4x4
                                end else begin
                                    block_y_counter <= block_y_counter + 1;
                                    state <= S_FETCH_16_SET_ADDR; // Próxima linha
                                end
                            end else begin
                                block_x_counter <= block_x_counter + 1;
                                state <= S_FETCH_16_SET_ADDR; // Próxima coluna
                            end
                        end
                        
                        // --- Estado Comum de Escrita ---
                        S_WRITE_RAM_AVG: begin
                            ram_wren_out <= 1'b1;
                            ram_addr_out <= ram_counter;
                            
                            if(zoom_enable == 3'b100) begin // Média 4x4
                                ram_data_out <= (sum_pixels + 12'd8) >> 4; // (soma)/16 com arredondamento
                            end else if (zoom_enable == 3'b011) begin // Média 2x2
                                ram_data_out <= ({2'b0, pixel_00} + {2'b0, pixel_01} + {2'b0, pixel_10} + {2'b0, pixel_11} + 2'd2) >> 2;
                            end else begin // Modo Normal 1x
                                ram_data_out <= rom_data_in;
                            end
                            
                            ram_counter <= ram_counter + 1;
                            state <= S_PROCESS_PIXEL;
                        end
                        
                        S_DONE: begin
                            done <= 1'b1;
                            ram_wren_out <= 1'b0;
                        end
                        
                        default: state <= S_IDLE;
                    endcase
                end // FIM do case(tipo_alg)
 // FIM MEDIA BLOCOS ===============================================

               4'b0010: begin
    //====================================================================
    //==== VIZINHO MAIS PRÓXIMO (ZOOM IN 1x, 2x, 4x)
    //====================================================================
    case (state)
        S_IDLE: begin
            pixel_counter <= 0;
            ram_counter   <= 0;
            zoom_phase    <= 0;
            done          <= 1'b0;
            ram_wren_out  <= 1'b0;

            if (zoom_enable == 3'b000) begin
                // Modo 1x: limpa apenas as bordas
                state <= S_CLEAR_BORDERS;
            end else begin
                // <<< MUDANÇA AQUI
                // Modos 2x e 4x: limpa a tela inteira antes de desenhar
                state <= S_CLEAR_ALL;
            end
        end

        // <<< NOVO ESTADO ADICIONADO
        // Limpa toda a RAM para os modos 2x e 4x
        S_CLEAR_ALL: begin
            ram_wren_out <= 1'b1;
            ram_data_out <= 8'h00; // Preto
            ram_addr_out <= ram_counter;

            if (ram_counter < RAM_SIZE - 1) begin
                ram_counter <= ram_counter + 1;
            end else begin
                // Terminou de limpar, prepara para desenhar
                ram_counter   <= 0;
                pixel_counter <= 0;
                state         <= S_SET_ADDR;
            end
        end

        S_CLEAR_BORDERS: begin
            // Lógica para limpar bordas (apenas para o modo 1x)
            if (current_y < NO_ZOOM_OFFSET_Y ||
                current_y >= NO_ZOOM_OFFSET_Y + ROM_IMG_H ||
                current_x < NO_ZOOM_OFFSET_X ||
                current_x >= NO_ZOOM_OFFSET_X + ROM_IMG_W) begin

                ram_wren_out <= 1'b1;
                ram_data_out <= 8'h00; // Preto
                ram_addr_out <= ram_counter;
            end else begin
                ram_wren_out <= 1'b0;
            end

            if (ram_counter < RAM_SIZE - 1) begin
                ram_counter <= ram_counter + 1;
            end else begin
                // Terminou de limpar, reseta o contador para desenhar a imagem
                pixel_counter <= 0;
                state         <= S_SET_ADDR;
            end
        end

        S_SET_ADDR: begin
            rom_addr_out <= pixel_counter;
            state        <= S_READ_ROM;
        end

        S_READ_ROM: begin
            rom_data_reg <= rom_data_in;
            state        <= S_WRITE_RAM;
        end

        S_WRITE_RAM: begin
            ram_wren_out <= 1'b1;
            ram_data_out <= rom_data_reg;

            if (zoom_enable == 3'b010) begin // MODO ZOOM 4X
                ram_addr_out <= ((rom_y * 4) + local_offset_y + ZOOM4X_OFFSET_Y) * RAM_WIDTH +
                                ((rom_x * 4) + local_offset_x + ZOOM4X_OFFSET_X);

                if (zoom_phase == 4'b1111) begin
                    zoom_phase <= 4'b0000;
                    if (pixel_counter < ROM_SIZE - 1) begin
                        pixel_counter <= pixel_counter + 1;
                        state <= S_SET_ADDR;
                    end else begin
                        state <= S_DONE;
                    end
                end else begin
                    zoom_phase <= zoom_phase + 1;
                    state <= S_WRITE_RAM;
                end

            end else if (zoom_enable == 3'b001) begin // MODO ZOOM 2X
                case(zoom_phase[1:0])
                    2'b00: ram_addr_out <= ((rom_y * 2) + 0 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 0 + ZOOM_OFFSET_X);
                    2'b01: ram_addr_out <= ((rom_y * 2) + 0 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 1 + ZOOM_OFFSET_X);
                    2'b10: ram_addr_out <= ((rom_y * 2) + 1 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 0 + ZOOM_OFFSET_X);
                    2'b11: ram_addr_out <= ((rom_y * 2) + 1 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 1 + ZOOM_OFFSET_X);
                endcase

                if (zoom_phase[1:0] == 2'b11) begin
                    zoom_phase <= 4'b0000;
                    if (pixel_counter < ROM_SIZE - 1) begin
                        pixel_counter <= pixel_counter + 1;
                        state <= S_SET_ADDR;
                    end else begin
                        state <= S_DONE;
                    end
                end else begin
                    zoom_phase <= zoom_phase + 1;
                    state <= S_WRITE_RAM;
                end

            end else begin // MODO SEM ZOOM (1X)
                ram_addr_out <= (rom_y + NO_ZOOM_OFFSET_Y) * RAM_WIDTH +
                                (rom_x + NO_ZOOM_OFFSET_X);

                if (pixel_counter < ROM_SIZE - 1) begin
                    pixel_counter <= pixel_counter + 1;
                    state <= S_SET_ADDR;
                end else begin
                    state <= S_DONE;
                end
            end
        end

        S_DONE: begin
            done <= 1'b1;
            ram_wren_out <= 1'b0;
        end

        default: state <= S_IDLE;
    endcase
end // FIM VIZINHO MAIS PRÓXIMO ===============================================
       
               4'b0011: begin 
							 // =================================================================================================
							 //  VIZINHO MAIS PRÓXIMO (1x, 2x, 0.5x, 0.25x)
							 // =================================================================================================
							 case (state)
								  VZ05_IDLE: begin
										ram_counter <= 0;
										done <= 1'b0;
										ram_wren_out <= 1'b0;
										state <= VZ05_CLEAR_FRAME; // Limpa a tela inteira primeiro
								  end
								  
								  VZ05_CLEAR_FRAME: begin
										ram_wren_out <= 1'b1;
										ram_data_out <= 8'h00; // Preto
										ram_addr_out <= ram_counter;
										
										if (ram_counter < RAM_SIZE - 1) begin
											 ram_counter <= ram_counter + 1;
										end else begin
											 ram_counter <= 0;
											 ram_wren_out <= 1'b0;
											 state <= VZ05_PROCESS_PIXEL;
										end
								  end
								  
								  VZ05_PROCESS_PIXEL: begin
										if (ram_counter >= RAM_SIZE) begin
											 state <= VZ05_DONE;
										end else begin
											 ram_wren_out <= 1'b0;
											 
											 // --- MODO ZOOM OUT 0.5x ---
											 if (zoom_enable == 3'b011) begin 
												  if (current_y >= ZOOM_OUT_OFFSET_Y && current_y < ZOOM_OUT_OFFSET_Y + (ROM_IMG_H / 2) &&
														current_x >= ZOOM_OUT_OFFSET_X && current_x < ZOOM_OUT_OFFSET_X + (ROM_IMG_W / 2)) begin
														
														temp_x = (current_x - ZOOM_OUT_OFFSET_X) * 2;
														temp_y = (current_y - ZOOM_OUT_OFFSET_Y) * 2;
														
														src_x <= temp_x[7:0];
														src_y <= temp_y[6:0];
														
														state <= VZ05_SET_ROM_ADDR;
												  end else begin
														// Fora da área de desenho, apenas avança para o próximo pixel
														ram_counter <= ram_counter + 1;
														state <= VZ05_PROCESS_PIXEL;
												  end
											 
											 // --- NOVO MODO ZOOM OUT 0.25x ---
											 end else if (zoom_enable == 3'b0100) begin
												  if (current_y >= ZOOM_OUT_025_OFFSET_Y && current_y < ZOOM_OUT_025_OFFSET_Y + (ROM_IMG_H / 4) &&
														current_x >= ZOOM_OUT_025_OFFSET_X && current_x < ZOOM_OUT_025_OFFSET_X + (ROM_IMG_W / 4)) begin
														
														temp_x = (current_x - ZOOM_OUT_025_OFFSET_X) * 4;
														temp_y = (current_y - ZOOM_OUT_025_OFFSET_Y) * 4;
														
														src_x <= temp_x[7:0];
														src_y <= temp_y[6:0];
														
														state <= VZ05_SET_ROM_ADDR;
												  end else begin
														// Fora da área de desenho, apenas avança para o próximo pixel
														ram_counter <= ram_counter + 1;
														state <= VZ05_PROCESS_PIXEL;
												  end

											 // --- MODO NORMAL 1:1 ---
											 end else if (zoom_enable == 3'b000) begin
												  if (current_y >= NORMAL_OFFSET_Y && current_y < NORMAL_OFFSET_Y + ROM_IMG_H &&
														current_x >= NORMAL_OFFSET_X && current_x < NORMAL_OFFSET_X + ROM_IMG_W) begin
														
														src_x <= current_x - NORMAL_OFFSET_X;
														src_y <= current_y - NORMAL_OFFSET_Y;
														
														state <= VZ05_SET_ROM_ADDR;
												  end else begin
														ram_counter <= ram_counter + 1;
														state <= VZ05_PROCESS_PIXEL;
												  end
											 end else begin
												  if (current_y >= NORMAL_OFFSET_Y && current_y < NORMAL_OFFSET_Y + ROM_IMG_H &&
														current_x >= NORMAL_OFFSET_X && current_x < NORMAL_OFFSET_X + ROM_IMG_W) begin
														
														src_x <= current_x - NORMAL_OFFSET_X;
														src_y <= current_y - NORMAL_OFFSET_Y;
														
														state <= VZ05_SET_ROM_ADDR;
												  end else begin
														ram_counter <= ram_counter + 1;
														state <= VZ05_PROCESS_PIXEL;
												  end
											 end
										end
								  end
								  
								  VZ05_SET_ROM_ADDR: begin
										rom_addr_out <= src_y * ROM_IMG_W + src_x;
										state <= VZ05_READ_ROM;
								  end
								  
								  VZ05_READ_ROM: begin
										rom_data_reg <= rom_data_in;
										state <= VZ05_WRITE_RAM;
								  end
								  
								  VZ05_WRITE_RAM: begin
										ram_wren_out <= 1'b1;
										ram_data_out <= rom_data_reg;
										ram_addr_out <= ram_counter;
										ram_counter <= ram_counter + 1;
										state <= VZ05_PROCESS_PIXEL;
								  end
								  
								  VZ05_DONE: begin
										done <= 1'b1;
										ram_wren_out <= 1'b0;
								  end
								  
								  default: state <= VZ05_IDLE;
							 endcase
						end // END VIZINHO 0.5X ===================================================================
                
                4'b0100: begin 

							 //====================================================================
							 //==== ALGORITMO DE REPLICAÇÃO DE PIXELS (1x, 2x, 4x)
							 //====================================================================

							 case (state)

								  S_IDLE: begin
										pixel_counter <= 0;
										ram_counter   <= 0;
										zoom_phase    <= 0;
										done          <= 1'b0;
										ram_wren_out  <= 1'b0;

										if (zoom_enable == 3'b000) begin
											 // 1x → apenas bordas
											 state <= S_CLEAR_BORDERS;
										end else begin
											 // 2x e 4x → limpar tudo antes de desenhar
											 state <= S_CLEAR_ALL;
										end
								  end

								  // NOVO ESTADO: limpa toda a RAM em 2x e 4x
								  S_CLEAR_ALL: begin
										ram_wren_out <= 1'b1;
										ram_data_out <= 8'h00; // Preto
										ram_addr_out <= ram_counter;

										if (ram_counter < RAM_SIZE - 1) begin
											 ram_counter <= ram_counter + 1;
										end else begin
											 ram_counter <= 0;
											 pixel_counter <= 0;
											 state <= S_SET_ADDR; // Começa a desenhar a imagem
										end
								  end

								  S_CLEAR_BORDERS: begin
										// Limpa apenas as bordas no modo 1x
										if (current_y < NO_ZOOM_OFFSET_Y || 
											 current_y >= NO_ZOOM_OFFSET_Y + ROM_IMG_H ||
											 current_x < NO_ZOOM_OFFSET_X || 
											 current_x >= NO_ZOOM_OFFSET_X + ROM_IMG_W) begin

											 ram_wren_out <= 1'b1;
											 ram_data_out <= 8'h00; // Preto
											 ram_addr_out <= ram_counter;
										end else begin
											 ram_wren_out <= 1'b0;
										end

										if (ram_counter < RAM_SIZE - 1) begin
											 ram_counter <= ram_counter + 1;
										end else begin
											 pixel_counter <= 0; // Prepara para desenhar a imagem no centro
											 state         <= S_SET_ADDR;
										end
								  end

								  S_SET_ADDR: begin
										rom_addr_out <= pixel_counter;
										state        <= S_READ_ROM;
								  end

								  S_READ_ROM: begin
										rom_data_reg <= rom_data_in;
										state        <= S_WRITE_RAM;
								  end

								  S_WRITE_RAM: begin
										ram_wren_out <= 1'b1;
										ram_data_out <= rom_data_reg;

										if (zoom_enable == 3'b010) begin // MODO 4X
											 ram_addr_out <= ((rom_y * 4) + local_offset_y + ZOOM4X_OFFSET_Y) * RAM_WIDTH + 
																  ((rom_x * 4) + local_offset_x + ZOOM4X_OFFSET_X);

											 if (zoom_phase == 4'b1111) begin
												  zoom_phase <= 4'b0000;
												  if (pixel_counter < ROM_SIZE - 1) begin
														pixel_counter <= pixel_counter + 1;
														state <= S_SET_ADDR;
												  end else begin
														state <= S_DONE;
												  end
											 end else begin
												  zoom_phase <= zoom_phase + 1;
												  state <= S_WRITE_RAM;
											 end

										end else if (zoom_enable == 3'b001) begin // MODO 2X
											 case(zoom_phase[1:0])
												  2'b00: ram_addr_out <= ((rom_y * 2) + 0 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 0 + ZOOM_OFFSET_X);
												  2'b01: ram_addr_out <= ((rom_y * 2) + 0 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 1 + ZOOM_OFFSET_X);
												  2'b10: ram_addr_out <= ((rom_y * 2) + 1 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 0 + ZOOM_OFFSET_X);
												  2'b11: ram_addr_out <= ((rom_y * 2) + 1 + ZOOM_OFFSET_Y) * RAM_WIDTH + ((rom_x * 2) + 1 + ZOOM_OFFSET_X);
											 endcase

											 if (zoom_phase[1:0] == 2'b11) begin
												  zoom_phase <= 4'b0000;
												  if (pixel_counter < ROM_SIZE - 1) begin
														pixel_counter <= pixel_counter + 1;
														state <= S_SET_ADDR;
												  end else begin
														state <= S_DONE;
												  end
											 end else begin
												  zoom_phase <= zoom_phase + 1;
												  state <= S_WRITE_RAM;
											 end

										end else begin // MODO 1X
											 ram_addr_out <= (rom_y + NO_ZOOM_OFFSET_Y) * RAM_WIDTH + (rom_x + NO_ZOOM_OFFSET_X);

											 if (pixel_counter < ROM_SIZE - 1) begin
												  pixel_counter <= pixel_counter + 1;
												  state <= S_SET_ADDR;
											 end else begin
												  state <= S_DONE;
											 end
										end
								  end

								  S_DONE: begin
										done <= 1'b1;
										ram_wren_out <= 1'b0;
								  end

								  default: state <= S_IDLE;

							 endcase
						end // FIM REPLICAÇÃO (1x, 2x, 4x)// FIM REPLICAÇÃO 2X
						
						
						4'b1111: begin
                    case (state)
                        S_IDLE: begin
                            ram_counter <= 0;
                            done <= 1'b0;
                            ram_wren_out <= 1'b0;
                            state <= S_PROCESS_PIXEL;
                        end

                        S_PROCESS_PIXEL: begin
                            if (ram_counter >= RAM_SIZE) begin
                                state <= S_DONE;
                            end else begin
                                // Verifica se o pixel atual da RAM está dentro da área da imagem centralizada
                                if (current_y >= NORMAL_OFFSET_Y && current_y < NORMAL_OFFSET_Y + ROM_IMG_H &&
                                    current_x >= NORMAL_OFFSET_X && current_x < NORMAL_OFFSET_X + ROM_IMG_W)
                                begin
                                    // Se estiver na área da imagem, calcula o endereço da ROM correspondente
                                    src_x_base <= current_x - NORMAL_OFFSET_X;
                                    src_y_base <= current_y - NORMAL_OFFSET_Y;
                                    state <= S_READ_ROM; // Próximo estado: buscar o pixel da ROM
                                end 
                                else begin
                                    // Se estiver nas bordas, escreve preto diretamente
                                    ram_wren_out <= 1'b1;
                                    ram_data_out <= 8'h00;
                                    ram_addr_out <= ram_counter;
                                    ram_counter <= ram_counter + 1;
                                    state <= S_PROCESS_PIXEL; // Continua no mesmo estado
                                end
                            end
                        end
                        
                        S_READ_ROM: begin
                            // Define o endereço da ROM e prepara para escrever na RAM no próximo ciclo
                            rom_addr_out <= src_y_base * ROM_IMG_W + src_x_base;
                            ram_wren_out <= 1'b0;
                            state <= S_WRITE_RAM;
                        end

                        S_WRITE_RAM: begin
                            // O dado da ROM está disponível em rom_data_in, escreve na RAM
                            ram_wren_out <= 1'b1;
                            ram_data_out <= rom_data_in;
                            ram_addr_out <= ram_counter;
                            ram_counter <= ram_counter + 1;
                            state <= S_PROCESS_PIXEL; // Volta para processar o próximo pixel da RAM
                        end

                        S_DONE: begin
                            done <= 1'b1;
                            ram_wren_out <= 1'b0;
                        end

                        default: state <= S_IDLE;
                    endcase
                end// nada selecionado ================================
						
            endcase
        end
    end
endmodule
