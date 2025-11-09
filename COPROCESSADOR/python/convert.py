from PIL import Image

def imagem_para_bin_cinza(imagem_path, bin_path):
    # Abre a imagem
    img = Image.open(imagem_path)
    
    # Converte para tons de cinza (modo 'L')
    img = img.convert('L')
    
    # Pega os dados dos pixels como bytes
    dados = img.tobytes()
    
    # Salva os dados brutos em um arquivo binário
    with open(bin_path, 'wb') as f:
        f.write(dados)

    print(f"Imagem em tons de cinza convertida para binário e salva em: {bin_path}")

# Exemplo de uso
imagem_para_bin_cinza('image.png', 'saida_cinza.bin')
