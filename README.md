# Granja Fantástica (Farm Simulator)

Roblox idle game. Criás animales de granja en tu propia parcela, generás **dinero** pasivo, subís de rareza, jugás con hasta 3 amigos más (4 jugadores por mapa).

**Pivot history**: Fruits (validado, funcionando) → Ducks (descartado en diseño) → **Animals (actual, specs cerradas, listo para Fase 0)**.

---

## 1. Concepto core

Jugador entra a un servidor de **máximo 4 jugadores**. Cada uno tiene su propia granja. Coloca animales que generan **dinero/segundo** según especie + rareza. Usa ese dinero para rollear más animales en el **altar** (gacha) y mejorar su granja. Sin fusión/duplicado — cada pull de rareza alta es un logro en sí mismo, la satisfacción viene de la rareza obtenida, no de combinar copias.

Toda la infraestructura de RollService/UpgradeService/IncomeService/DataManager **ya existe y funciona** (validado con frutas). Este pivot es: renombrar + nuevo roster de animales + nuevo mapa 4-jugadores + altar reskin + belts de movimiento.

---

## 2. Animales (roster)

### Base solicitada
Pollo, Cerdo, Vaca, Caballo, Conejo, Oso

### Roster sugerido, aprobado por el usuario
| Tier económico | Animal |
|---|---|
| Starter | Pollo, Conejo |
| Común-Medio | Cerdo, Oveja, Cabra |
| Medio-Alto | Vaca, Caballo, Llama |
| Alto | Oso, Búfalo, Avestruz |
| Exótico | Pavo Real, Alpaca Dorada, Tigre Blanco |
| Mítico/tope | Dragón de Granja, Fénix, Unicornio |

**Modelos 3D**: el usuario los va a diseñar con Claude Design y los va a pasar cuando estén listos, animal por animal. `AnimalModel.luau` (ex `PlantModel.luau`) queda con un modelo placeholder genérico hasta recibir cada diseño — no bloquea el resto del desarrollo.

---

## 3. Sistema de rarezas

### Rarezas base (ya implementado, reusar tal cual)
Común → Poco Común → Raro → Épico → Legendario → Mítico

### Sin fusión / sin duplicado / sin cofres
**Decisiones confirmadas**:
- No hay mecánica de combinar duplicados. Conseguir una rareza alta debe sentirse como un golpe de suerte grande, autoconclusivo.
- Duplicados **solo se acumulan** — se colocan en otro slot libre de la granja (más animales = más dinero/s directo). No hay venta ni sumidero de duplicados.
- **Cofres descartados.** Única forma de conseguir animales es el Roll/Altar. No implementar `ChestService`.

### Slots de granja y progresión por rebirth
Cada granja tiene spots físicos donde colocar animales. Fórmula de capacidad (reemplaza la curva anterior de "saltos cada 5 rebirths"):

- Base: **10 slots** (sin rebirths)
- Cada rebirth: **+1 slot**
- Máximo: **30 slots** → se llega con **20 rebirths** (10 + 20×1 = 30)

Cambios en `GameConfig`: `PLOT_MAX_SIZE` 20→30, `POTS_PER_UNLOCK` 2→1, `REBIRTHS_PER_UNLOCK` 5→1 (o simplificar a `getMaxPots(rebirths) = min(10 + rebirths, 30)` directamente, sin necesidad de la lógica de "saltos").

**Animación de animales colocados**: cada animal en su spot necesita una leve animación idle (bobbing/respiración/movimiento sutil) — no deben verse rígidos/estáticos. A implementar en Fase 6 (visual) sobre `AnimalModel`.

### Eje de variantes (Secreto, Fantasmal + nuevas "locas")
Eje **independiente** de la rareza — no es un 7mo/8vo escalón, es una capa que se aplica ENCIMA de cualquier resultado. Confirmado por el usuario: quiere **más variantes tipo Arcoíris, Exótico, etc.**, y estas variantes no solo suman multiplicador de dinero — **cambian la estética del animal** (color, partículas, efecto). La lista final de variantes y su apariencia se define **una vez que existan los modelos base de cada animal** (depende del diseño en Claude Design).

Variantes ya definidas como concepto:
- **Secreto**: probabilidad fija ultra baja en cualquier roll, reemplaza el resultado normal.
- **Fantasmal**: exclusiva de eventos limitados, translúcida + partículas.
- **Arcoíris / Exótico / etc.**: a definir en Fase 6, junto con el diseño visual de cada animal.

Probabilidades exactas de Secreto/Fantasmal: **pendiente de balanceo**, se ajusta en playtesting (Fase 8) según cuánto tarda un jugador promedio en conseguir uno.

---

## 4. Altar (gacha) — confirmado, ya casi construido

El usuario mandó referencia visual: personaje parado frente a un altar, el altar va mostrando en negro/silueta animales aleatorios (suspenso), y al final revela el resultado real ya decidido según la suerte del jugador — **esto es exactamente el comportamiento que ya tiene `RollAnimation.luau`** (teasers en `"???"` + rarezas altas mientras gira, resultado real ya calculado en servidor antes de empezar la animación).

**Altar por jugador, no compartido.** Cada granja tiene su(s) propio(s) altar(es) — esto ya es como está construido: los pedestales (hasta 5, comprables) viven dentro de la parcela de cada jugador, y `wirePrompts` ya valida ownership (`plot:GetAttribute("OwnerUserId") ~= triggerPlayer.UserId then return`). El hub central queda solo para tiendas/items de tiempo limitado, sin altar compartido.

**Efecto visual 100% local/privado.** El usuario pidió que el efecto de spin/reveal lo vea únicamente quien lo activa, no el resto de jugadores (mejor rendimiento + mejor sensación personal del pull). **Esto ya está satisfecho por la arquitectura actual**: `RollService.requestRoll` manda el resultado con `rollResultRemote:FireClient(player, ...)` — solo al jugador dueño del roll, nunca un `FireAllClients`. No requiere cambio de lógica, solo confirmar que el reskin visual (Fase 3) no rompa este patrón.

**Lo que falta**: solo reskin visual — reemplazar el pedestal genérico por un modelo de altar (columna dorada, efecto de brillo/partículas tipo la referencia), y el cartel "ROLL" por algo tipo "SPIN DETAILS" mostrando las probabilidades (esto además cubre el requisito de compliance de Roblox: probabilidades visibles en UI). Cero cambio de lógica de red/servidor.

**Cofres: descartados.** Ver sección 3.

---

## 5. Monetización con Robux

**Confirmado: se hace al final, una vez terminado el juego principal** (todas las fases de gameplay completas y pulidas primero). Ideas ya anotadas para cuando se retome:

- Game Passes: 2x Suerte, Auto-Recolectar, Slot de Granja Extra (dentro del tope de 30), VIP
- Developer Products: paquetes de rolls instantáneos, boost de dinero, boost de suerte temporal
- Exclusivos cosméticos de Robux, evitando vender directamente el Secreto/Mítico (mejor vender mejoras de probabilidad o cosmética pura)

**Compliance obligatorio**: probabilidades exactas visibles en la UI del altar antes de publicar (política de Roblox para random item generators).

---

## 6. Mapa: 4 jugadores, layout confirmado

Referencia del usuario (sketch): **franja central vertical** = "lugar donde van a estar las tiendas / objetos de tiempo limitado, etc" (el hub). A los costados, **2 granjas a la izquierda, 2 granjas a la derecha** (una arriba, una abajo de cada lado) — 4 granjas total, cada una con forma irregular/orgánica (no rectángulos perfectos, según el dibujo).

```
┌─────────┐  ┌────────┐  ┌─────────┐
│ Granja  │  │  HUB   │  │ Granja  │
│ Jugador │  │ Tiendas│  │ Jugador │
│   1     │  │  Items │  │   2     │
├─────────┤  │ tiempo │  ├─────────┤
│ Granja  │  │limitado│  │ Granja  │
│ Jugador │  │        │  │ Jugador │
│   3     │  └────────┘  │   4     │
└─────────┘              └─────────┘
```

- Reusar `PlotLayout`/`PlotService` (renombrar a `FarmLayout`/`FarmService`), cambiar el cálculo de posiciones de grilla-fórmula a **4 posiciones fijas** (izquierda-arriba, izquierda-abajo, derecha-arriba, derecha-abajo) alrededor del hub central.
- El hub central es zona neutral (no pertenece a ningún jugador): tiendas, objetos de tiempo limitado. **Sin altar en el hub** — cada altar vive dentro de su granja (ver sección 4).

### Belts de movimiento rápido (nuevo, confirmado)
Referencia del usuario: camino tipo cinta transportadora con patrón de chevrones (flechas), formando un circuito en la zona del hub. Función: moverse rápido entre granjas y el hub sin tener que correr.

**Implementación sugerida**: parts alargados con textura/decal de chevrones + zona de velocidad (al pisar, sube el `WalkSpeed` del jugador o aplica un `LinearVelocity`/`BodyVelocity` en la dirección de la cinta — patrón clásico de "conveyor belt" en Roblox, no requiere sistema nuevo, solo un `ConveyorService` chico detectando `Touched`/`Region` sobre esos parts). Circuito recorriendo el hub y quizás bordeando las 4 granjas.

---

## 7. Roadmap por etapas (ingeniería, paso a paso)

### ✅ Fase 0 — Fundación del pivot (renombrado) — COMPLETA
`Plant → Animal`, `Plot → Farm`, `speciesName → animalSpecies`, `PlantModel → AnimalModel`, `PlotLayout → FarmLayout`, `PlotService → FarmService`, `coins → money`. Validado en vivo: roll, colocar, quitar, upgrades — todo probado por remotos en Studio, sin errores. Workspace limpiado de basura de templates/testing (rig leftover, decals huérfanos, SpawnLocations duplicados, ScreenGui vacío, efectos post-proceso sin usar).

### ✅ Fase 1 — Roster + economía base + curva de slots nueva — COMPLETA
`GameConfig.SPECIES`: 17 animales (Pollo, Conejo, Cerdo, Oveja, Cabra, Vaca, Caballo, Llama, Oso, Búfalo, Avestruz, Pavo Real, Alpaca Dorada, Tigre Blanco, Dragón de Granja, Fénix, Unicornio — los últimos 3 con `fixedRarity=6`, exclusivos de rolls Mítico). `STARTING_ANIMAL` = Pollo. Fórmula de slots nueva confirmada por test en vivo: `rb0=10 rb1=11 ... rb20=30` (tope). Emojis de `UITheme.SPECIES_ICONS` actualizados como bonus (no bloqueante, cosmética de bajo costo). Modelos 3D siguen en placeholder — entran en Fase 5 con los diseños de Claude Design.

### ✅ Fase 2 — Mundo multijugador (4 granjas + hub) — COMPLETA
`FarmLayout.getFarmOrigin` reescrito: 4 posiciones fijas (2 columnas separadas por el hub, 2 filas cada una), `FarmLayout.buildHub()` construye la franja central neutral (cartel "🏪 ZONA DE TIENDAS · Próximamente", sin lógica todavía). `FARM_COUNT = 4`. Cada granja mantiene sus propios pedestales/altares — sin altar compartido en el hub. Validado en vivo: 30 pots por granja, asignación/liberación correcta, mapa completo (4 granjas + hub) reconstruido persistente en Studio.

**Bug encontrado y arreglado durante el testing**: el jugador aparecía en el `SpawnLocation` compartido en vez de su granja — `player.Character` todavía no existía cuando `FarmService.assign()` corría (race condition). Arreglado con `player.CharacterAdded:Connect(...)`, que además ahora cubre respawns (morir/resetear te devuelve a tu propia granja, no al spawn compartido).

### Fase 3 — Altar reskin
Modelo visual de altar (columna dorada + partículas) reemplazando el pedestal genérico. Cartel de probabilidades visible ("SPIN DETAILS"). Confirmar que el efecto sigue siendo 100% privado por jugador (`FireClient`, no `FireAllClients`). Sin cambio de lógica — `RollAnimation.luau` ya se comporta como se pidió.

### Fase 4 — Belts de movimiento
`ConveyorService`: parts con textura de chevrones + boost de velocidad al pisarlos, circuito en el hub (y opcionalmente bordeando las granjas).

### Fase 5 — Variantes locas + visual completo
Una vez que el usuario pase los modelos de Claude Design: cargar `AnimalModel` reales, definir lista final de variantes (Arcoíris/Exótico/etc.) con su estética propia, aplicar glow/partículas/color por variante. **Animación idle en los animales colocados** (bobbing/movimiento sutil, no rígidos). Reskin completo de HUD (íconos, textos, tema granja). Sonidos por especie/variante.

### Fase 6 — Progresión de largo plazo
Rebirth trigger (ya existe el sistema de desbloqueo de slots, falta el botón — ahora +1 slot por rebirth hasta 30). Quests diarios. Leaderboard.

### Fase 7 — Polish + playtesting
Balance de curvas con datos reales. Ajuste de probabilidad Secreto/Fantasmal/variantes según cuánto tarda un jugador promedio en conseguir cada una — a cargo de Claude, sin necesidad de aprobación previa de cada número.

### Fase 8 — Monetización (al final, juego principal ya terminado)
Definir gamepasses/dev products concretos con el usuario. Implementar. **Compliance: desglose de probabilidades visible en UI antes de publicar.**

---

## 8. Notas técnicas (para el próximo Claude)

- Todo el motor de rolls/upgrades/income/data **ya está construido y probado en vivo** con Roblox Studio MCP (RollService, UpgradeService, IncomeService, DataManager, PlotService).
- El roll es **100% autoritativo en servidor** — el cliente solo anima, nunca decide resultado. Mantener este patrón para variantes también.
- El comportamiento de altar pedido por el usuario (silueta random + reveal por suerte, y **visible solo para quien lo activa**) **ya está implementado** en `RollAnimation.luau` + `RollService` (`FireClient` al dueño, nunca `FireAllClients`) — no reinventar, solo reskinnear visualmente.
- Rojo (`rojo serve`) sincroniza `src/` → Studio automáticamente. MCP de Roblox Studio conectado y funcional para testing en vivo.
- **No implementar**: `FusionService` (descartado), `ChestService`/cofres (descartado), venta de duplicados (descartado — solo se acumulan).
- Curva de slots vieja (saltos de +2 cada 5 rebirths, tope 20) **queda obsoleta** — reemplazar por +1 slot por rebirth, tope 30 (sección 3).

---

**Last updated**: specs 100% cerradas (roster, rarezas, mapa 4-jugadores, altar privado por jugador, belts, slots por rebirth). Sin preguntas pendientes — listo para arrancar Fase 0.
