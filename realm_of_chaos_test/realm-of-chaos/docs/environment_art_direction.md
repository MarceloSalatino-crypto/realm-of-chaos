# Direção de arte ambiental e padrão de qualidade dos biomas

## Status

O **Bosque Profanado** é o primeiro bioma aprovado e passa a ser a referência de
qualidade ambiental do projeto. A referência é o resultado visual alcançado —
coesão, composição, profundidade e leitura — e não a reprodução literal de sua
paleta, vegetação, materiais ou formas nos demais biomas.

Este documento define os princípios que devem ser reutilizados nas Ruínas
Glaciais, na Catedral do Vazio e em biomas futuros. Cada um precisa começar por
uma vertical slice própria e construir uma identidade original.

## Regra principal

Um bioma não pode parecer um plano uniforme com sprites espalhados sobre ele.
Chão, detalhes, obstáculos, landmarks, sombras e atmosfera devem formar uma
composição contínua. O cenário precisa parecer ter produzido os objetos — e ter
sido transformado por eles — em vez de apenas recebê-los como sobreposições.

O ambiente deve sustentar a fantasia do lugar sem competir com jogador,
inimigos, projéteis, pickups ou telegraphs.

## 1. Composição por regiões semânticas

A geração visual deve produzir regiões com funções composicionais distintas.
Elas não são salas rígidas nem zonas de gameplay novas: são estados do ambiente
que orientam densidade, materiais, agrupamentos e enquadramento.

### `OPEN_ARENA`

- Preserva espaço negativo e silhuetas limpas para combate intenso.
- Continua rica no próprio chão: mudanças suaves de material, manchas,
  microtextura, detritos baixos e pequenas diferenças de luminosidade.
- Evita grandes massas ambientais no centro e concentra peso visual nas bordas.
- Nunca pode parecer uma área inacabada ou uma textura única ampliada.

### `DENSE_REGION`

- Usa massas ambientais sobrepostas, alturas diferentes e oclusão controlada.
- Agrupa elementos por relação visual, não por distribuição uniforme.
- Combina objeto dominante, elementos de apoio, transição de solo, sombra de
  contato e pequenos detalhes que expliquem o agrupamento.
- Precisa transmitir profundidade sem esconder ameaças ou rotas próximas.

### `NATURAL_CORRIDOR`

- Conecta regiões por curvas e mudanças graduais do terreno.
- Pode ficar evidente, desaparecer parcialmente e reaparecer.
- É enquadrado por massas laterais, raízes, pedras baixas ou vegetação, sem
  virar uma estrada perfeita nem um corredor artificial.
- A direção visual deve existir no mundo, e não somente nos dados do gerador.

### `TRANSITION`

- Impede cortes bruscos entre áreas abertas, densas, corredores e landmarks.
- Mistura estados vizinhos em proporções graduais.
- Usa bordas irregulares, interrupções e invasão de um material pelo outro.
- Deve parecer transformação natural do solo, nunca uma faixa ou decalque.

### `LANDMARK_REGION`

- O terreno reage à presença da estrutura.
- Inclui uma área de assentamento coerente: solo exposto, raízes, pedras,
  detritos, desgaste, sombra e pequenos elementos narrativos.
- A silhueta principal permanece reconhecível, mas não parece colada sobre o
  chão nem isolada em um vazio.
- Caminhos podem chegar, contornar ou desaparecer perto do landmark.

## 2. Variação do terreno em diferentes escalas

A riqueza do chão vem da combinação de três escalas. Nenhuma delas deve tentar
resolver o mapa sozinha.

### Escala ampla — composição macro

- Grandes estados de material e luminosidade organizam a tela.
- Formam áreas abertas, massas densas, corredores e zonas de transição.
- Devem atravessar mais de uma tela e evitar repetição evidente.

### Escala média — estrutura local

- Manchas de solo, ombros de trilha, áreas de assentamento e agrupamentos de
  vegetação quebram a uniformidade macro.
- Ligam obstáculos e landmarks ao material do chão.
- Variam largura, curvatura, intensidade e continuidade.

### Escala pequena — acabamento

- Pedras pequenas, folhas, galhos, rachaduras, raízes finas e resíduos oferecem
  leitura próxima.
- Permanecem com baixo contraste e escala coerente.
- São usados para reforçar uma região existente, não para preencher espaço ao
  acaso.

As três escalas precisam compartilhar paleta, perspectiva, pixel density e
direção de luz.

## 3. Áreas abertas versus regiões densas

Aberto não significa vazio, e denso não significa cobrir toda a tela.

- Áreas abertas recebem complexidade principalmente no chão e nas bordas.
- Regiões densas recebem complexidade também na silhueta e na sobreposição.
- Transições alternam gradualmente entre essas duas hierarquias.
- O ritmo do mapa deve variar: abertura, compressão, conexão, descoberta e nova
  abertura.
- A distribuição não deve uniformizar o mapa inteiro no nível máximo de detalhe
  da vertical slice.

## 4. Agrupamentos ambientais intencionais

Elementos ambientais são organizados em pequenas composições com motivo visual:

1. Um elemento dominante define a massa e a silhueta.
2. Elementos secundários apoiam sua direção e assimetria.
3. Detalhes baixos conectam a composição ao terreno.
4. Uma sombra de contato confirma peso e posição.
5. Uma área de transição altera o chão ao redor.

Evitar:

- espaçamento regular;
- rotação e escala aleatórias sem relação com a composição;
- elementos equivalentes competindo pela mesma importância;
- árvores, pedras ou estruturas completas sem base visual;
- repetição reconhecível da mesma composição em telas próximas.

## 5. Assentamento visual de objetos e landmarks

Árvores, pedras e estruturas precisam parecer apoiadas no mundo.

- A base deve tocar o chão em um ponto visual claro.
- Raízes, cascalho, terra deslocada, detritos ou desgaste unem objeto e terreno.
- O material sob o objeto pode ser mais escuro, exposto ou comprimido.
- O contorno inferior não deve formar halo, borda clara ou transparência
  incompatível com o chão.
- Objetos com colisão mantêm leitura mais sólida; elementos atravessáveis devem
  parecer baixos ou incorporados ao terreno.

## 6. Sombras de contato e profundidade

- Todo objeto grande recebe sombra de contato proporcional à sua base.
- A sombra ancora o objeto; não deve virar um glow preto ao redor do sprite.
- Sobreposição, escala, contraste, valor e oclusão controlada criam planos de
  profundidade.
- Sombras amplas podem ajudar agrupamentos, mas não podem esconder hazards,
  pickups ou inimigos.
- Luz ambiente e pontos mágicos devem conectar personagens e cenário sem lavar
  a pixel art ou criar gradientes excessivos.

## 7. Transições entre estados do terreno

Uma transição convincente segue uma mistura gradual, por exemplo:

`material base → detalhe ralo → mistura de materiais → material dominante → detalhe local`

Regras:

- usar máscaras contínuas e bordas irregulares;
- interromper e variar a intensidade;
- permitir que vegetação e resíduos invadam a transição;
- evitar quadrados, halos, emendas claras e diferenças de coloração;
- evitar fileiras de sprites tentando simular um material contínuo.

## 8. Controle de contraste e legibilidade do combate

A hierarquia visual deve permanecer estável:

1. Telegraphs e perigos imediatos.
2. Jogador, inimigos e ataques.
3. Pickups e elementos interativos.
4. Landmarks e obstáculos sólidos.
5. Detalhes ambientais e microtextura.

O chão usa contraste baixo a médio. Cores brilhantes são reservadas para pontos
de interesse, corrupção, magia ou informação funcional. Em carga alta, a
silhueta dos atores precisa continuar legível contra qualquer estado do terreno.

## 9. Vertical slice como gate artístico

Cada novo bioma deve seguir esta ordem:

1. Definir identidade própria: materiais, paleta, formas, história ambiental e
   linguagem de luz.
2. Criar uma vertical slice isolada com composição completa, não apenas assets
   separados.
3. Aprovar visualmente as cinco situações obrigatórias.
4. Registrar a vertical slice aprovada como referência direta daquele bioma.
5. Integrar no mapa principal comparando constantemente cada região equivalente.
6. Reprovar qualquer região principal mais pobre, uniforme ou desconectada que
   sua referência.
7. Validar jogo real, suíte funcional, testes visuais e performance.

As cinco situações obrigatórias são:

- `OPEN_ARENA` sem combate;
- `NATURAL_CORRIDOR`;
- `DENSE_REGION`;
- `LANDMARK_REGION` com sua transição;
- `COMBAT` real sob carga.

Aprovar a tecnologia não aprova a arte. A integração só termina quando o mapa
principal parece uma expansão natural da vertical slice.

## 10. O que reutilizar e o que não copiar

### Reutilizar

- regiões semânticas;
- composição em escalas macro, média e micro;
- agrupamentos intencionais;
- transições contínuas;
- áreas de assentamento;
- sombras de contato;
- hierarquia de contraste;
- processo de vertical slice e comparação;
- batching, orçamento de nós e gates de performance.

### Não copiar do Bosque

- paleta verde-azulada e marrom;
- árvores profanadas, raízes e vegetação morta;
- barro e trilhas antigas como solução universal;
- altar enraizado e linguagem de ruína florestal;
- distribuição exata, curvas ou composições prontas;
- texturas e sprites do Bosque como substitutos de uma identidade nova.

As Ruínas Glaciais devem descobrir sua própria relação entre gelo, neve, pedra,
fratura, soterramento e luz fria. A Catedral do Vazio deve descobrir sua própria
relação entre arquitetura, pavimento, corrupção, ritual, escala e escuridão.

## 11. Baseline aprovado do Bosque Profanado

Estes números documentam a implementação aprovada; não são metas obrigatórias
para outros biomas:

- cinco trajetos visuais orgânicos;
- cinco regiões semânticas cobertas;
- 1.200 detalhes ambientais processados em lotes;
- 36 obstáculos físicos preservados;
- 26 árvores físicas integradas à composição visual aprovada;
- quatro landmarks com áreas de assentamento;
- terreno contínuo com variação macro, média e pequena;
- gameplay, colisão, spawn e progressão desacoplados da composição visual.

Gates de performance do projeto:

- média máxima: **14,0 ms**;
- p95 máximo: **22,0 ms**.

## 12. Fontes de verdade no projeto

- `scripts/forest_terrain_composer.gd`: composição semântica e mistura contínua
  do Bosque aprovado.
- `scripts/world_environment_builder.gd`: distribuição do ambiente e integração
  do compositor ao mapa real.
- `assets/generated/forest_vertical_slice/`: assets da vertical slice aprovada.
- `tests/forest_vertical_slice_visual_test.gd`: referência visual isolada.
- `tests/forest_terrain_integration_visual_test.gd`: cinco capturas no
  `world.tscn` real e gate de performance da integração.
- `tests/world_environment_builder_test.gd`: garantias de colisão, contagem,
  regiões e isolamento entre biomas.

## Checklist de aprovação de um novo bioma

- [ ] O chão possui variedade contínua nas três escalas.
- [ ] A área aberta é rica sem atrapalhar o combate.
- [ ] A região densa possui agrupamento, assentamento e profundidade.
- [ ] O corredor conecta regiões sem parecer uma estrada artificial.
- [ ] As transições não possuem emendas, halos ou decalques evidentes.
- [ ] Árvores, pedras e estruturas parecem tocar o chão.
- [ ] Landmarks transformam visualmente sua área próxima.
- [ ] A paleta e a iluminação pertencem à identidade do bioma.
- [ ] A carga de combate permanece legível.
- [ ] As cinco capturas igualam a qualidade da vertical slice aprovada.
- [ ] O mapa principal foi comparado região por região com a referência.
- [ ] Gameplay, colisão e progressão não foram alterados pela integração visual.
- [ ] Suíte, testes gráficos e benchmarks passaram.
