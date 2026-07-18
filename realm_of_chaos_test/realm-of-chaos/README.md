# Realm of Chaos — Survivor Vertical Slice

Uma evolução completa do protótipo original para um loop no estilo survivor: movimento fluido, ataques automáticos, hordas crescentes, experiência, escolhas de build e chefes em uma sessão de 25 minutos.

## Como jogar

1. Abra `project.godot` no Godot 4.3 ou superior.
2. Pressione **F6/F5** ou clique em **Executar projeto**.
3. Selecione **Iniciar Ritual**.

### Controles

- **WASD / setas / analógico esquerdo:** movimento.
- **Mouse / teclado / controle:** escolha de upgrades e menus.
- **Esc:** pausar ou continuar.
- Os ataques são automáticos e miram a ameaça mais próxima.

## Conteúdo implementado

- Sessão completa de 25 minutos: Normal (0–5), Difícil (5–10), Caos (10–15) e Modo Inferno (15–25).
- Seis arquétipos visuais: espreitador, morcego, mago, brutamonte, crânio de brasa e chefe.
- Novo protagonista **Caçador do Eclipse**, com cabelo branco, meia-máscara de osso, sobretudo azul-noturno e cachecol carmesim.
- Arma inicial sorteada entre Besta do Caos, Lâmina Sombria, Cetro das Almas e Cajado da Nova; cada resultado troca a aparência completa da personagem.
- Animações quadro a quadro: caminhada em quatro poses e ataque em quatro poses específicas para cada arma, sem deformação artificial dos membros.
- Seis folhas de animação inimigas com locomoção, preparação e golpe/conjuração próprios de cada arquétipo.
- Chefes nas transições e no confronto final, elites aleatórios e escalada de vida/dano/quantidade.
- Quatro armas evolutivas: Seta do Caos, Lâminas Sombrias, Órbita de Almas e Nova do Vazio.
- Oito passivos para dano, velocidade, vida, coleta, armadura, regeneração e crítico.
- Cristais de experiência, corações, níveis e três escolhas por nível com raridades.
- HUD completo: vida, XP, tempo restante, estágio, abates, armas e barra de chefe.
- Game Over ou Vitória aos 25 minutos, com tempo, eliminações, nível, reinício, menu e recordes persistentes.
- Arena de floresta corrompida com 310 elementos decorativos determinísticos.
- Suporte a teclado e controle.

## Teste automatizado

Com um executável do Godot disponível:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
```

Saída esperada:

```text
SMOKE TEST OK: 25 minutos, 4 fases, animações, combate, upgrades e telas finais validados
```

## Estrutura principal

- `scenes/world.tscn`: composição da arena e camadas de atores.
- `scripts/world.gd`: diretor de hordas, fases, chefes, drops e fluxo da partida.
- `scripts/player.gd`: movimento, atributos, XP, armas e upgrades.
- `scripts/enemies/enemy.gd`: comportamento genérico orientado por arquétipo.
- `scripts/hud.gd`: interface, level-up, pausa e telas finais.
- `scripts/game_defs.gd`: catálogo central de inimigos, estágios e melhorias.
- `assets/generated/`: herói, bestiário e chão originais integrados ao jogo.
- `tests/smoke_test.gd`: validação executável dos sistemas essenciais.

## Próximas evoluções sugeridas

- Música dinâmica e efeitos sonoros.
- Segundo personagem jogável com arma inicial própria.
- Evoluções de arma por combinações de passivos.
- Baús de chefes, relíquias e metaprogressão entre partidas.
- Mais biomas e eventos especiais por estágio.
