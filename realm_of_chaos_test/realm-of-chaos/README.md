# Realm of Chaos — Survivor Vertical Slice

Uma evolução completa do protótipo original para um loop no estilo survivor: movimento direto, ataques automáticos, hordas crescentes, experiência, escolhas de build e chefes em uma sessão de 10 minutos.

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

- Sessão completa de 10 minutos com quatro estágios de intensidade.
- Seis arquétipos visuais: espreitador, morcego, mago, brutamonte, crânio de brasa e chefe.
- Chefes a cada três minutos, elites aleatórios e escalada de vida/dano/quantidade.
- Quatro armas evolutivas: Seta do Caos, Lâminas Sombrias, Órbita de Almas e Nova do Vazio.
- Oito passivos para dano, velocidade, vida, coleta, armadura, regeneração e crítico.
- Cristais de experiência, corações, níveis e três escolhas por nível com raridades.
- HUD completo: vida, XP, tempo restante, estágio, abates, armas e barra de chefe.
- Pausa, vitória, derrota, reinício, recordes e contagem de vitórias persistentes.
- Arena de floresta corrompida com 310 elementos decorativos determinísticos.
- Suporte a teclado e controle.

## Teste automatizado

Com um executável do Godot disponível:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
```

Saída esperada:

```text
SMOKE TEST OK: mundo, 6 inimigos, combate, drops e upgrades validados
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
