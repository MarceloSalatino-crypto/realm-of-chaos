# Laboratório de Vertical Slices

O laboratório oferece dois tipos de acesso sem substituir a cena principal nem gravar o progresso:

- **Bosque Profanado · Produção:** usa o `world.tscn`, o fluxo de campanha, colisões, spawns, landmarks e `ForestTerrainComposer` reais. Apenas o `map_id` é sobrescrito em memória para `profaned_forest`.
- **Vertical slices:** versões artísticas isoladas, sem cronômetro, horda ou colisões do ambiente de produção.

## Abrir pelo editor

1. Abra `res://scenes/biome_vertical_slice_lab.tscn`.
2. Execute a cena atual com **F6**.
3. Escolha **Bosque Profanado** ou **Ruínas Glaciais** no seletor.

Para jogar o Bosque real, escolha **BOSQUE PROFANADO · PRODUÇÃO**.

## Abrir pela linha de comando

```powershell
godot --path . res://scenes/biome_vertical_slice_lab.tscn
```

Para entrar diretamente nas Ruínas Glaciais:

```powershell
godot --path . res://scenes/biome_vertical_slice_lab.tscn -- --slice=frozen
```

Use `--slice=forest` para abrir diretamente o Bosque Profanado.

Para entrar diretamente no Bosque real de produção, sem tocar no save:

```powershell
godot --path . res://scenes/biome_vertical_slice_lab.tscn -- --slice=forest_production
```

## Controles

- **WASD / setas:** mover o caçador.
- **1:** arena aberta.
- **2:** corredor natural/via soterrada.
- **3:** região densa.
- **4:** landmark.
- **5:** transição.
- **Tab ou Esc:** abrir/fechar o seletor de biomas.
- **F1:** ocultar/mostrar a barra de desenvolvimento.
- **F2 (somente Bosque de produção):** mostrar/ocultar os limites reais de troncos, raízes grossas, pedras e partes sólidas dos landmarks.

Na visualização F2, verde identifica bosques individuais, âmbar as massas densas,
cinza as pedras e ciano os landmarks. A cápsula branca é a área física do
caçador. Copas, folhas, vegetação baixa e os vãos sem forma colorida continuam
atravessáveis.

No modo de produção, o laboratório mantém a campanha funcionando e define `suppress_save` antes de adicionar o `world.tscn` à árvore. O save real é apenas lido para obter personagem e metaprogressão; seleção de mapa, recordes, conquistas e progresso não são gravados. A cena principal configurada em `project.godot` não é alterada.
