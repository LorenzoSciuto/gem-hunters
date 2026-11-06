## PowerUpData.gd
## Data resource for one entry of the SurpriseBox random pool.
## One .tres per power-up type lives in resources/powerups/.
extends Resource
class_name PowerUpData

## Which power-up this entry grants.
@export var type: Constants.PowerUpType = Constants.PowerUpType.NONE

## Relative spawn probability. Higher = more common.
@export var pool_weight: int = 1
