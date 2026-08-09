# Realm of Chaos — Survivor Vertical Slice

Uma evolução completa do protótipo original para um loop no estilo survivor: movimento fluido, ataques automáticos, hordas crescentes, experiência, escolhas de build e chefes em uma sessão de 25 minutos.

## Como jogar

1. Abra `project.godot` no Godot 4.7.1 ou em uma versão compatível da série 4.7.
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
- Cada caçador possui uma arma inicial temática fixa: Caçador do Eclipse/Besta do Caos, Oráculo Glacial/Cetro das Almas, Cavaleiro Rubro/Lâmina Sombria e Autômato do Vazio/Cajado da Nova.
- Animações quadro a quadro: caminhada em quatro poses e ataque em quatro poses específicas para cada arma, sem deformação artificial dos membros.
- Folhas de animação inimigas com locomoção, preparação e golpe/conjuração próprios de cada arquétipo.
- Mini-chefes exclusivos aos 5, 10, 15 e 20 minutos; o Soberano do Caos surge aos 25 minutos e precisa ser derrotado para concluir a fase.
- Baú animado após cada mini-chefe, com três escolhas e dez relíquias acumuláveis que alteram projéteis, crítico, roubo de vida, sobrevivência, recarga e dano contra chefes.
- Chefes com arenas fechadas próprias, três fases, padrões alternados, ataques sinalizados, projéteis radiais, investidas, invocações e golpes de área.
- Nove armas evolutivas. Além do arsenal original, existem Foice Hemática, Grimório Proibido, Martelo Rúnico, Relíquia da Tempestade e Ídolo do Enxame.
- Novas evoluções: Ceifadora Carmesim, Códice do Fim, Martelo do Cataclismo, Tempestade Eterna e Olho da Legião.
- Oito passivos para dano, velocidade, vida, coleta, armadura, regeneração e crítico.
- Cristais de experiência, corações, níveis e três escolhas por nível com raridades, receitas de evolução visíveis, três rerolls, três banimentos e duas opções de pular por partida.
- Limite de seis armas simultâneas para tornar cada build uma decisão real.
- Depois que armas e passivos da build chegam ao máximo, novos níveis viram cura e Essência automaticamente.
- HUD completo: vida, alerta de perigo, XP, tempo restante, contagem para o próximo chefe, estágio, abates, Essência, eventos, build em duas linhas e barra de chefe/fase.
- Números de dano, críticos, congelamento de impacto, telemetria, tremor de câmera e partículas com orçamento visual sob carga.
- Três músicas ambientes em rotação com crossfade, faixa procedural de chefe e 23 samples reais de efeitos no bus SFX.
- Mixagem protegida por buses separados de música/efeitos, compressão, limiters, limite de vozes e prioridade para eventos essenciais.
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
- Índice espacial de inimigos, pooling de projéteis inimigos, LOD visual, limites de projéteis/efeitos e fusão de cristais excedentes.
- Benchmarks separados para a referência sintética de IA com 300 inimigos e para a carga combinada no teto real de 90 inimigos, com pickups, perigos, chefe, projéteis e efeitos.
- Suporte a teclado e controle.

## Testes automatizados

Com o Godot disponível no terminal, o smoke test principal pode ser executado assim:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
```

A suíte funcional está dividida por componente e por sistema. Para executar todos os testes funcionais:

```powershell
Get-ChildItem tests -Filter *_test.gd |
  Where-Object Name -notin @(
    "performance_test.gd",
    "visual_load_performance_test.gd",
    "max_build_drop_performance_test.gd"
  ) |
  Sort-Object Name |
  ForEach-Object {
    & godot --headless --path . --fixed-fps 60 --script "res://tests/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
```

Os três benchmarks possuem critérios reais de aprovação:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/performance_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/visual_load_performance_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/max_build_drop_performance_test.gd
```

Eles falham se a média ultrapassar 14,0 ms ou o p95 ultrapassar 22,0 ms.

### Teste manual rápido no editor

- **F7:** avança o relógio até o próximo mini-chefe/chefe.
- **F8:** libera as nove armas evoluídas.
- **F9:** derrota o chefe ativo para testar recompensas e avanço de fase.
- **F10:** concede um nível imediatamente para revisar cartas e combinações.

Os atalhos só funcionam em execução pelo editor e não são habilitados em uma exportação final.

## Estrutura principal

- `scenes/world.tscn`: composição da arena e camadas de atores.
- `scripts/world.gd`: fachada pública, estado compartilhado e ordem principal da partida.
- `scripts/world_spatial_index.gd`: consultas espaciais de inimigos.
- `scripts/world_environment_builder.gd`: construção do bioma, perigos, obstáculos e santuários.
- `scripts/world_persistence.gd`: perfil, opções, recordes e conquistas persistentes.
- `scripts/world_director.gd`: cronograma de hordas, eventos, elites e chefes.
- `scripts/world_entity_manager.gd`: criação, limites e pooling de entidades da partida.
- `scripts/world_run_flow.gd`: HUD, recompensas, upgrades e encerramento da sessão.
- `scripts/player.gd`: fachada pública, estado, movimento e ciclo de física do jogador.
- `scripts/player_progression.gd`: XP, níveis, passivos, relíquias e evoluções.
- `scripts/player_combat.gd`: armas, ataques, projéteis e aquisição de alvos.
- `scripts/player_visual_controller.gd`: animação, orientação e feedback visual do jogador.
- `scripts/enemies/enemy.gd`: fachada pública, estado, dano e ciclo principal do inimigo.
- `scripts/enemies/enemy_motion.gd`: direção, separação e deslocamento.
- `scripts/enemies/enemy_abilities.gd`: ataques, habilidades e fases de chefes.
- `scripts/enemies/enemy_visual_controller.gd`: animação, LOD e sinalização visual.
- `scripts/hud.gd`: interface, level-up, pausa e telas finais.
- `scripts/game_defs.gd`: catálogo central de inimigos, chefes, evoluções, biomas e legado.
- `scripts/audio_director.gd`: música, samples de SFX, buses, fades, prioridade e proteção da mixagem.
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
- `tests/`: caracterização dos componentes extraídos, integração de gameplay, áudio, orientação visual, UI e regressões.
- `tests/performance_test.gd`: referência de IA e busca espacial com 300 inimigos.
- `tests/visual_load_performance_test.gd`: carga combinada no teto global de 90 inimigos, com 520 pickups, 18 perigos, 276 projéteis e 120 efeitos.
- `tests/max_build_drop_performance_test.gd`: custo de 520 mortes após a build ficar completa.

## Espaço para futuras expansões

- Mixagem final, faixas próprias por bioma e temas dedicados para cada chefe.
- Remapeamento completo de controles e localização para outros idiomas.
- Novas fases, árvores de personagem, padrões de chefe e desafios rotativos.
