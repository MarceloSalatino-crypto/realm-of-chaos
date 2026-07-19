# Assets originais gerados

Estes assets foram criados especificamente para **Realm of Chaos** com o gerador de imagens integrado do Codex e processados para uso direto no Godot.

## Protagonista

- `hero_eclipse_hunter.png`: arte principal do novo Caçador do Eclipse.
- `hero_anim_chaos_bolt.png`: folha 4×2 com caminhada e disparo da Besta do Caos.
- `hero_anim_shadow_blades.png`: folha 4×2 com caminhada e sequência de corte da Lâmina Sombria.
- `hero_anim_soul_orbit.png`: folha 4×2 com caminhada e conjuração do Cetro das Almas.
- `hero_anim_chaos_nova.png`: folha 4×2 com caminhada e conjuração do Cajado da Nova.

Em cada folha da protagonista, a linha superior contém quatro poses de locomoção e a inferior quatro poses de ataque. A arma sorteada troca a folha inteira, portanto corpo, mãos e arma permanecem visualmente coerentes.

## Inimigos

- `enemy_anim_prowler.png`: passada, preparação e golpe de cutelo.
- `enemy_anim_bat.png`: ciclo de asas e mergulho.
- `enemy_anim_mage.png`: flutuação e conjuração.
- `enemy_anim_brute.png`: marcha pesada e esmagamento.
- `enemy_anim_ember.png`: oscilação das chamas e investida.
- `enemy_anim_void_knight.png`: passada, preparação e corte do chefe.

Cada inimigo usa quatro quadros horizontais: dois de locomoção, um de preparação e um de ataque/conjuração.

## Mini-chefes e chefe final

- `boss_ossuary_colossus.png`: Colosso do Ossuário, mini-chefe dos 5 minutos.
- `boss_glacial_archon.png`: Arconte Glacial, mini-chefe dos 10 minutos.
- `boss_infernal_reaper.png`: Ceifador Infernal, mini-chefe dos 15 minutos.
- `boss_void_titan.png`: Titã do Vazio, mini-chefe dos 20 minutos.
- `boss_chaos_sovereign.png`: Soberano do Caos, confronto final dos 25 minutos.

Cada chefe usa quatro quadros horizontais: locomoção A/B, preparação e execução do ataque. Todos foram processados por chroma key, possuem alfa e dimensões divisíveis por quatro.

## Mundo e legado

- `corrupted_forest_ground.png`: terreno ortográfico repetível da floresta corrompida.
- `frozen_ruins_ground.png`: piso repetível das Ruínas Glaciais.
- `void_cathedral_ground.png`: piso repetível da Catedral do Vazio.
- `boss_reward_chest.png`: folha horizontal de quatro quadros — fechado, energizado, abrindo e aberto — usada nas recompensas dos mini-chefes.
- `map_landmarks_v1.png`: atlas horizontal com Altar Rubro, Obelisco Cronal, Santuário das Almas e Portal Fraturado.
- Os PNGs anteriores do Guardião, atlas e peças modulares foram preservados como material de legado, mas não são usados pela animação atual.

Direção visual: pixel art de fantasia sombria, silhuetas legíveis na escala de gameplay, protagonista em azul-noturno/prata/carmesim e inimigos com identidades cromáticas próprias. Sem texto, marcas ou elementos de terceiros.

Os sprites ativos possuem canal alfa e cantos transparentes. As dimensões das folhas foram validadas para divisão exata em seus quadros.

O baú foi criado com o gerador de imagens integrado, em modo de geração nativa, a partir de um prompt de sprite dark fantasy ortográfico com quatro quadros exatos, ferro negro, ouro antigo e gema violeta sobre chroma `#00ff00`. O fundo foi removido pelo utilitário oficial `remove_chroma_key.py`; o PNG final mede 2172×724, possui alfa válido e largura divisível por quatro.

Os marcos do mapa foram gerados no mesmo modo e direção artística, com quatro células horizontais exatas sobre chroma uniforme. O atlas final também mede 2172×724, possui canal alfa validado, cantos transparentes e largura divisível por quatro.
