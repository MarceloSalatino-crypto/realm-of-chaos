# Realm of Chaos — Survivor Vertical Slice

Uma evolução completa do protótipo original para um loop no estilo survivor: movimento fluido, ataques automáticos, hordas crescentes, experiência, escolhas de build e chefes em uma sessão de 25 minutos.

## Como jogar

1. Abra `project.godot` no Godot 4.3 ou superior.
2. Pressione **F5** ou clique em **Executar projeto** para começar pelo menu. **F6** executa apenas a cena aberta no editor e pode pular o menu.
3. Selecione **Iniciar Ritual**.

### Controles

- **WASD / setas / analógico esquerdo:** movimento.
- **Espaço / botão A:** esquiva curta com invulnerabilidade e recarga.
- **M:** ocultar ou exibir o minimapa.
- **Mouse / teclado / controle:** escolha de upgrades e menus.
- **Esc:** pausar ou continuar.
- Os ataques são automáticos e miram a ameaça mais próxima.

## Conteúdo implementado

- Sessão completa de 25 minutos: Normal (0–5), Difícil (5–10), Caos (10–15) e Modo Inferno (15–25).
- Onze inimigos jogáveis no diretor de hordas, incluindo bombardeiro, necromante, arqueiro, assassino, enxame e guardião de suporte.
- Novo protagonista **Caçador do Eclipse**, com cabelo branco, meia-máscara de osso, sobretudo azul-noturno e cachecol carmesim.
- Quatro caçadores selecionáveis, cada um com bônus e habilidade acionada pela esquiva: Rajada do Eclipse, Pulso Glacial, Contra-ataque Rubro ou Sobrecarga Arcana.
- Arma inicial sorteada entre Besta do Caos, Lâmina Sombria, Cetro das Almas e Cajado da Nova; cada resultado troca a aparência completa da personagem.
- Animações quadro a quadro: caminhada em quatro poses e ataque em quatro poses específicas para cada arma, sem deformação artificial dos membros.
- Folhas de animação inimigas com locomoção, preparação e golpe/conjuração próprios de cada arquétipo.
- Mini-chefes exclusivos aos 5, 10, 15 e 20 minutos; o Soberano do Caos surge aos 25 minutos e precisa ser derrotado para concluir a fase.
- Baú animado após cada mini-chefe, com três escolhas e dez relíquias acumuláveis que alteram projéteis, crítico, roubo de vida, sobrevivência, recarga e dano contra chefes.
- Chefes com arenas fechadas próprias, três fases, padrões alternados, ataques sinalizados, projéteis radiais, investidas, invocações e golpes de área.
- Nove armas evolutivas. Além do arsenal original, existem Foice Hemática, Grimório Proibido, Martelo Rúnico, Relíquia da Tempestade e Ídolo do Enxame.
- Novas evoluções: Ceifadora Carmesim, Códice do Fim, Martelo do Cataclismo, Tempestade Eterna e Olho da Legião.
- Oito passivos para dano, velocidade, vida, coleta, armadura, regeneração e crítico.
- Cristais de experiência, corações, níveis e três escolhas por nível com raridades, três rerolls, três banimentos e duas opções de pular por partida.
- Limite de seis armas simultâneas para tornar cada build uma decisão real.
- HUD completo: vida, XP, tempo restante, estágio, abates, Essência, eventos, armas e barra de chefe/fase.
- Números de dano, críticos, congelamento de impacto, telemetria, tremor de câmera, partículas, efeitos sonoros e trilha adaptativa sintetizados em tempo real.
- Game Over ao morrer ou Vitória após derrotar o chefe final, com reinício da fase ou avanço para o próximo bioma.
- Tela final detalhada com dano total, maior fonte de dano, dano recebido, chefes vencidos, relíquias e novas conquistas.
- Metaprogressão permanente com Essência e melhorias de dano, vida, movimento e crítico.
- Sete conquistas persistentes e painel de perfil integrado ao menu.
- Três biomas encadeados: Bosque Profanado, Ruínas Glaciais e Catedral do Vazio.
- Física própria por bioma: raízes reduzem movimento, placas de gelo diminuem tração e fendas do Vazio causam dano contínuo.
- Mapa estruturado em zonas, com clareira central, caminhos radiais, 24 obstáculos físicos e quatro marcos visuais exploráveis.
- Santuários do Altar Rubro, Obelisco Cronal, Árvore das Almas e Portal Fraturado concedem bênçãos temporárias de combate.
- Minimap dinâmico mostra jogador, santuários, chefes e baús de recompensa.
- Eventos especiais: Lua de Sangue, Tempestade de Almas, Eclipse e Chuva do Vazio.
- Arena com 310 elementos decorativos determinísticos e variação visual por bioma.
- Movimento com aceleração, frenagem e inércia; separação local faz inimigos contornarem uns aos outros em vez de formar um bloco estático.
- Entrada cinematográfica de chefes e sinalização do perigo do terreno no HUD.
- Opções persistentes de música, efeitos sonoros, tremor de câmera, intensidade de flashes e tela cheia.
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
- **F8:** libera as nove armas evoluídas.
- **F9:** derrota o chefe ativo para testar recompensas e avanço de fase.

Os atalhos só funcionam em execução pelo editor e não são habilitados em uma exportação final.

Testes adicionais:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/boss_timeline_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/performance_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/profile_rewards_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_expansion_test.gd
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
- `scripts/reward_chest.gd`: animação, aproximação e abertura dos baús de mini-chefes.
- `scripts/arena_hazard.gd`: perigos interativos e modificadores físicos de cada bioma.
- `scripts/boss_arena.gd`: limites, identidade visual e progressão das arenas de chefes.
- `scripts/homing_eye.gd`: invocações perseguidoras do Ídolo do Enxame.
- `scripts/lightning_effect.gd`: corrente visual da Relíquia da Tempestade e do Autômato.
- `scripts/weapon_flash.gd`: apresentação do atlas das novas armas durante os ataques.
- `scripts/map_overlay.gd`: clareiras, zonas, rotas e borda visual da arena.
- `scripts/map_landmark.gd`: santuários exploráveis, colisão e ativação das bênçãos.
- `scripts/minimap.gd`: navegação em tempo real e marcadores importantes.
- `assets/generated/`: herói, bestiário e chão originais integrados ao jogo.
- `tests/smoke_test.gd`: validação executável dos sistemas essenciais.
- `tests/boss_timeline_test.gd`: simulação acelerada dos cinco confrontos e da vitória.
- `tests/performance_test.gd`: teste de carga com 300 inimigos e busca espacial.
- `tests/profile_rewards_test.gd`: validação do menu inicial, mapa, esquiva, santuários, baús, relíquias e estatísticas.
- `tests/combat_expansion_test.gd`: validação das nove armas, evoluções, habilidades, escolhas avançadas e arenas.

## Espaço para futuras expansões

- Trilhas autorais gravadas e mixagem profissional por bioma.
- Remapeamento completo de controles e localização para outros idiomas.
- Novas fases, árvores de personagem, padrões de chefe e desafios rotativos.
