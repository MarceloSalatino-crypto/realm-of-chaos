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
- Onze inimigos jogáveis no diretor de hordas, incluindo bombardeiro, necromante, arqueiro, assassino, enxame e guardião de suporte.
- Novo protagonista **Caçador do Eclipse**, com cabelo branco, meia-máscara de osso, sobretudo azul-noturno e cachecol carmesim.
- Arma inicial sorteada entre Besta do Caos, Lâmina Sombria, Cetro das Almas e Cajado da Nova; cada resultado troca a aparência completa da personagem.
- Animações quadro a quadro: caminhada em quatro poses e ataque em quatro poses específicas para cada arma, sem deformação artificial dos membros.
- Folhas de animação inimigas com locomoção, preparação e golpe/conjuração próprios de cada arquétipo.
- Mini-chefes exclusivos aos 5, 10, 15 e 20 minutos; o Soberano do Caos surge aos 25 minutos e precisa ser derrotado para concluir a fase.
- Chefes com três fases, ataques sinalizados no chão, projéteis radiais, investidas, invocações e golpes de área.
- Quatro armas evolutivas: Balista Abissal, Dança das Sombras, Devorador de Espíritos e Colapso do Vazio.
- Oito passivos para dano, velocidade, vida, coleta, armadura, regeneração e crítico.
- Cristais de experiência, corações, níveis e três escolhas por nível com raridades.
- HUD completo: vida, XP, tempo restante, estágio, abates, Essência, eventos, armas e barra de chefe/fase.
- Números de dano, críticos, congelamento de impacto, telemetria, tremor de câmera, partículas, efeitos sonoros e trilha adaptativa sintetizados em tempo real.
- Game Over ao morrer ou Vitória após derrotar o chefe final, com reinício da fase ou avanço para o próximo bioma.
- Metaprogressão permanente com Essência e melhorias de dano, vida, movimento e crítico.
- Três biomas encadeados: Bosque Profanado, Ruínas Glaciais e Catedral do Vazio.
- Eventos especiais: Lua de Sangue, Tempestade de Almas, Eclipse e Chuva do Vazio.
- Arena com 310 elementos decorativos determinísticos e variação visual por bioma.
- Índice espacial de inimigos, limites de projéteis/efeitos e teste de carga com 300 criaturas.
- Suporte a teclado e controle.

## Teste automatizado

Com um executável do Godot disponível:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
```

Saída esperada:

```text
SMOKE TEST OK: horda expandida, evoluções, eventos, metaprogressão, mini-chefes e chefe final validados
```

### Teste manual rápido no editor

- **F7:** avança o relógio até o próximo mini-chefe/chefe.
- **F8:** libera as quatro armas evoluídas.
- **F9:** derrota o chefe ativo para testar recompensas e avanço de fase.

Os atalhos só funcionam em execução pelo editor e não são habilitados em uma exportação final.

Testes adicionais:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/boss_timeline_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/performance_test.gd
```

## Estrutura principal

- `scenes/world.tscn`: composição da arena e camadas de atores.
- `scripts/world.gd`: diretor de hordas, fases, chefes, drops e fluxo da partida.
- `scripts/player.gd`: movimento, atributos, XP, armas e upgrades.
- `scripts/enemies/enemy.gd`: IA especializada, sinalização de ataques e fases de chefes.
- `scripts/hud.gd`: interface, level-up, pausa e telas finais.
- `scripts/game_defs.gd`: catálogo central de inimigos, chefes, evoluções, biomas e legado.
- `scripts/audio_director.gd`: efeitos sonoros procedurais sem dependência de arquivos externos.
- `scripts/damage_number.gd`: números flutuantes de dano, crítico e cura.
- `assets/generated/`: herói, bestiário e chão originais integrados ao jogo.
- `tests/smoke_test.gd`: validação executável dos sistemas essenciais.
- `tests/boss_timeline_test.gd`: simulação acelerada dos cinco confrontos e da vitória.
- `tests/performance_test.gd`: teste de carga com 300 inimigos e busca espacial.

## Próximas evoluções sugeridas

- Trilhas autorais gravadas e mixagem profissional por bioma.
- Segundo personagem jogável com arma inicial própria.
- Baús animados, relíquias raras e desafios diários.
- Configurações de áudio, acessibilidade e remapeamento de controles.
- Mais personagens, biomas e padrões de chefe.
