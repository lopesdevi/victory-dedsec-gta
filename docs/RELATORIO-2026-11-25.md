# Relatório de progresso: 25/11/2026

GTA VI (build Xbox Series) no PC pelo VIctory. Tudo aqui foi medido em uma máquina só: Windows
Server 2025, Xeon de 32 núcleos, 123 GB de RAM, NVIDIA RTX PRO 4500 (Blackwell, 32 GB).

## Onde chegamos

- **O prólogo (a prisão) foi jogado do começo ao fim** numa sessão só, com alguns bugs de textura.
- **Chegamos ao mundo aberto**: a primeira missão na água (o barco, "Follow the plane") roda com
  HUD, minimapa e objetivo; a tela de missão falhada e as opções de checkpoint funcionam.
- **Estabilidade: uma sessão de 140 minutos sem travar**, sem exceção e sem perda da placa. Quem
  fechou fomos nós.
- **Velocidade: 4 a 6 fps.** Mediana de 228 ms por frame (4,4 fps) com o mundo desenhado; os
  melhores trechos em 168 a 182 ms (5,5 a 6 fps).

## O que foi testado na sessão longa

| Trecho | O que vimos |
|---|---|
| Abertura | primeiro frame do mundo 129 s depois de abrir, com o cache de shaders já preenchido |
| Cutscene de abertura | passa inteira, iluminada, com os fades |
| Prisão | bloco de celas, corredores, colegas de cela, rosto e uniforme da personagem, avisos na tela |
| Fim do prólogo | o jogo gravou o save automático (12:22) |
| Mundo aberto | missão do barco; água com áreas pretas; tela "FAILED" com as opções de checkpoint aos 139 minutos |

Números da sessão: 140 minutos, cerca de 36 mil frames, 0 exceções, 0 falhas de GPU, 0 leituras
de disco fora de ordem, memória em ~27 GB (pico de 34,6 GB).

## O que mudou hoje

1. **Base nova.** Passamos a trabalhar em cima da `VIwork` do Trexies, que nesta placa roda mais
   longe e mais rápido que a nossa linha anterior (5 a 6 fps contra 3, sala iluminada, cerca de 70
   shaders a mais traduzidos). A linha anterior fica guardada no branch `linha-anterior`.
2. **Correção da fila do DirectStorage** (`77f25f8`), trazida da nossa linha anterior. Na base
   pura, 3 aberturas registraram de 8 a 10 leituras fora de ordem cada, e numa delas o rosto da
   personagem não foi desenhado. Com a correção: nenhuma em 140 minutos, rosto presente. Uma
   abertura ainda é pouco para dar como resolvido.
3. **Dois consertos de shaders de água** (`8410ab7`, `2210e63`): 4 programas que eram descartados
   em todo frame no mar aberto agora traduzem e passam no validador. Todas as outras 25.719
   traduções do pack ficaram byte a byte iguais. **O efeito no jogo ainda não foi medido.**

## O que falta

- **FPS.** Dos ~170 a 230 ms por frame no mundo aberto, cerca de 140 são CPU preparando cópias da
  memória do jogo; a placa leva só 14 a 24 ms.
- **Água.** Áreas pretas no mar aberto; ainda faltam 2 programas de água.
- **Luz.** Sem luz de ray tracing: o que o sol não alcança fica escuro.
- **Texturas.** Algumas erradas no prólogo.
- **Carregar o save pelo menu**: ainda não conferido.
- **Rosto**: confirmar em mais aberturas que não some mais.

## Prints

Em [`docs/screenshots`](screenshots): `01` a `05` prólogo, `06` mundo aberto (barco, com a água
preta), `07` tela de missão falhada aos 139 minutos, `08` o defeito do rosto na base antes da
correção.
