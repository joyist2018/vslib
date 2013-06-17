/*  
 * Copyright (c) 2013 LuKeM (Lucas Murawski)
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * 
 */

 
/**
 * \brief Provides many helpful entity functions.
 *
 *  The Entity class wraps many Valve functions as well as provide numerous
 *  helper functions that aid in the development of maps, mods, and mutations.
 */
class ::VSLib.Entity
{
	constructor(index)
	{
		if ("_ent" in index && "_idx" in index)
		{
			_ent = index._ent;
			_idx = index._idx;
		}
		else if ((typeof index) == "instance")
		{
			_ent = index;
			_idx = GetBaseIndex();
		}
		else if ((typeof index) == "integer")
		{
			_ent = Ent(index);
			_idx = index;
		}
		else if ((typeof index) == "string" && index.find("!") != 0)
		{
			_ent = Entities.FindByTarget (null, index);
			if (_ent == null)
				throw "Invalid targetname (target not found)";
			_idx = GetBaseIndex();
		}
		else
		{
			_ent = Ent(index);
			_idx = GetBaseIndex();
		}
	}
	
	
	function _typeof()
	{
		return "VSLIB_ENTITY";
	}
	
	function _cmp(other)
	{
		if ("_ent" in other && "_idx" in other)
		{
			if (_idx > other._idx)
				return 1;
			else if (_idx == other._idx)
				return 0;
			else if (_idx < other._idx)
				return -1;
		}
		else if ((typeof other) == "integer")
		{
			if (_idx > other)
				return 1;
			else if (_idx == other)
				return 0;
			else if (_idx < other)
				return -1;
		}
		else if ((typeof index) == "instance")
		{
			if (_ent > other)
				return 1;
			else if (_ent == other)
				return 0;
			else if (_ent < other)
				return -1;
		}
	}
	
	
	static _vsEntityClass = "VSLIB_ENTITY";
	_ent = null;
	_idx = null;
}

/**
 * Holds global entity data.
 *
 * \todo @TODO Perhaps move all of these into two distinct tables with KVs instead of leaving the KVs out in the EntData table
 */
::VSLib.EntData <-
{
	// single point_hurt data
	_lastHurt = -1
	_hurtIntent = -1
	_hurtDmg = 0
	_forcedHurt = false
	
	// repeating point_hurt data
	_continuousHurt = {}
	_continuousHurtIntent = {}
	_continuousHurtDmg = {}
	_continuousHurtCount = -1
	
	_objPickupTimer = {}
	_objBtnPickup = {}
	_objBtnThrow = {}
	_objOldBtnMask = {}
	_objHolding = {}
	
	_objValveTimer = {}
	_objValveHolding = {}
	_objValveThrowPower = {}
	_objValvePickupRange = {}
}



/**
 * Global definitions and constants.
 */
getconsttable()["InvalidEntity"] <- null;

// Teams
getconsttable()["UNKNOWN"] <- 0; /**< Anything that is unknown. */
getconsttable()["SPECTATORS"] <- 1;
getconsttable()["SURVIVORS"] <- 2;
getconsttable()["INFECTED"] <- 3;


// "Zombie" types, to be used with GetPlayerType()
getconsttable()["SURVIVOR"] <- 9;
getconsttable()["TANK"] <- 8;
getconsttable()["CHARGER"] <- 6;
getconsttable()["JOCKEY"] <- 5;
getconsttable()["SPITTER"] <- 4;
getconsttable()["HUNTER"] <- 3;
getconsttable()["BOOMER"] <- 2;
getconsttable()["SMOKER"] <- 1;
getconsttable()["COMMON"] <- 999;
getconsttable()["WITCH"] <- 7;



/**
 * Returns true if the entity is valid or false otherwise.
 * Sometimes, just because an entity or edict exists doesn't mean that
 * it hasn't freed up or become invalidated. Luckily, you will rarely use
 * thus function since VSLib uses it automatically.
 */
function VSLib::Entity::IsEntityValid()
{
	if (_ent == null)
		return false;
	
	if (!("IsValid" in _ent))
		return false;
	
	return _ent.IsValid();
}

/**
 * Gets the entity's real health.
 * If the entity is valid, the entity's health is returned; otherwise, null is returned.
 * The health includes any andrenaline or pill health.
 */
function VSLib::Entity::GetHealth()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	local hp = _ent.GetHealth();
	if (_ent.IsPlayer())
		hp += _ent.GetHealthBuffer();
	
	return hp;
}

/**
 * Gets the entity's raw health.
 * If the entity is valid, the entity's health is returned; otherwise, null is returned.
 * Raw health does not include temporary health.
 */
function VSLib::Entity::GetRawHealth()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return _ent.GetHealth();
}

/**
 * Hurts the entity by the specified damage.
 * If the entity is valid, the entity will be hurt with the specified damage type.
 * If you aren't sure what damage type you want to use, enter 0.
 */
function VSLib::Entity::Hurt(value, dmgtype = 0)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tointeger();
	dmgtype = dmgtype.tointeger();
	
	local point_hurt = g_ModeScript.CreateSingleSimpleEntityFromTable({ classname = "point_hurt", targetname = "vslib_tmp_" + UniqueString(), origin = GetLocation(), angles = QAngle(0,0,0), Damage = value, DamageType = dmgtype });
	
	// if the entity is not valid (e.g. entdata has reached the max), then try something else.
	if (!point_hurt)
	{
		Msg("Warning: Could not create point_hurt entity.");
		SetRawHealth(GetHealth() - value);
		return;
	}
	
	point_hurt.__KeyValueFromString("DamageTarget", _ent.GetName());
	
	::VSLib.EntData._lastHurt = point_hurt;
	::VSLib.EntData._hurtIntent = _ent;
	::VSLib.EntData._hurtDmg = value;
	::VSLib.EntData._forcedHurt = false;
	
	DoEntFire("!self", "Hurt", "", 0, point_hurt, point_hurt);
	DoEntFire("!self", "Kill", "", 0, null, point_hurt);
}

/**
 * Fires a specific input
 */
function VSLib::Entity::Input(input, value = "", delay = 0, activator = null)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (activator != null)
		DoEntFire("!self", input.tostring(), value.tostring(), delay.tofloat(), activator.GetBaseEntity(), _ent);
	else
		DoEntFire("!self", input.tostring(), value.tostring(), delay.tofloat(), null, _ent);
}

/**
 * Breaks the entity (if it is breakable)
 */
function VSLib::Entity::Break()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	Input("Break");
}

/**
 * Dispatches a keyvalue to the entity
 */
function VSLib::Entity::SetKeyValue(key, value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (typeof value == "instance")
		_ent.__KeyValueFromVector(key.tostring(), value);
	else
		_ent.__KeyValueFromString(key.tostring(), value.tostring());
}

/**
 * Hurts the entity by the specified damage but overrides any user damage modifiers.
 */
function VSLib::Entity::ForcedHurt(value, dmgtype = 0)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tointeger();
	dmgtype = dmgtype.tointeger();
	
	local point_hurt = g_ModeScript.CreateSingleSimpleEntityFromTable({ classname = "point_hurt", targetname = "vslib_tmp_" + UniqueString(), origin = GetLocation(), angles = QAngle(0,0,0), Damage = value, DamageType = dmgtype });
	
	// if the entity is not valid (e.g. entdata has reached the max), then try something else.
	if (!point_hurt)
	{
		Msg("Warning: Could not create point_hurt entity.");
		SetRawHealth(GetHealth() - value);
		return;
	}
	
	point_hurt.__KeyValueFromString("DamageTarget", _ent.GetName());
	
	::VSLib.EntData._lastHurt = point_hurt;
	::VSLib.EntData._hurtIntent = _ent;
	::VSLib.EntData._hurtDmg = value;
	::VSLib.EntData._forcedHurt = true;
	
	DoEntFire("!self", "Hurt", "", 0, point_hurt, point_hurt);
	DoEntFire("!self", "Kill", "", 0, null, point_hurt);
}

/**
 * Same as Hurt(), except it keeps hurting for the specified time.
 * It hurts at the specified interval.
 */
function VSLib::Entity::HurtTime(value, dmgtype, interval, time)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	//
	// Create the point hurt
	//
	value = value.tointeger();
	dmgtype = dmgtype.tointeger();
	time = time.tofloat();
	interval = interval.tofloat();
	
	local id = "vslib_tmp_" + UniqueString() + "a";
	
	local point_hurt = g_ModeScript.CreateSingleSimpleEntityFromTable({ classname = "point_hurt", targetname = id, origin = GetLocation(), angles = QAngle(0,0,0), Damage = value, DamageType = dmgtype, DamageDelay = interval });
	
	// if the entity is not valid (e.g. entdata has reached the max), then try something else.
	if (!point_hurt)
	{
		Msg("Warning: Could not create point_hurt entity.");
		return;
	}
	
	point_hurt.__KeyValueFromString("DamageTarget", _ent.GetName());
	
	//
	// Set up VSLib to use the data
	//
	::VSLib.EntData._continuousHurtCount++;
	::VSLib.EntData._continuousHurt[::VSLib.EntData._continuousHurtCount] <- point_hurt;
	::VSLib.EntData._continuousHurtIntent[::VSLib.EntData._continuousHurtCount] <- _ent;
	::VSLib.EntData._continuousHurtDmg[::VSLib.EntData._continuousHurtCount] <- value;
	
	//
	// Connect outputs to VSLib
	//
	point_hurt.ConnectOutput("OnKilled", "Killed");
	point_hurt.ValidateScriptScope();
	local scr = point_hurt.GetScriptScope();
	scr.ent <- point_hurt;
	scr.target <- ::VSLib.Entity(_ent);
	scr.Killed <- function()
	{
		foreach (idx, val in ::VSLib.EntData._continuousHurt)
		{
			if (val == this.ent)
			{
				delete ::VSLib.EntData._continuousHurt[idx];
				delete ::VSLib.EntData._continuousHurtIntent[idx];
				delete ::VSLib.EntData._continuousHurtDmg[idx];
			}
		}
	}
	
	scr[id] <- function()
	{
		if (this.target.IsEntityValid())
			this.ent.SetOrigin(this.target.GetLocation());
	}
	
	AddThinkToEnt(point_hurt, id);
	
	DoEntFire("!self", "TurnOn", "", 0, point_hurt, point_hurt);
	DoEntFire("!self", "Kill", "", time, null, point_hurt);
}

/**
 * Sets the entity's raw health.
 * If the entity is valid, the entity's health is set.
 * Setting raw health removes any existing temp health.
 */
function VSLib::Entity::SetRawHealth(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.SetHealth(value.tointeger());
}

/**
 * Sets the entity's health.
 * If the entity is valid, the entity's health is set.
 * This will also incapacitate the player if the input value is
 * less than or equal to 0.
 */
function VSLib::Entity::SetHealth(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tointeger();
	
	local hp = GetHealth();
	if (value <= 0)
	{
		SetRawHealth(1);
		Hurt(1, 0);
	}
	else if (value < hp)
		Hurt(hp - value, 0);
	else
		SetRawHealth(value);
}

/**
 * Sets the entity's maximum possible health without modifying the entity's current health.
 * If the entity is valid, the entity's max health is set.
 */
function VSLib::Entity::SetMaxHealth(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
		
	value = value.tointeger();
	
	_ent.__KeyValueFromInt("max_health", value);
}

/**
 * Vomits on the Entity
 */
function VSLib::Entity::Vomit()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if ("HitWithVomit" in _ent)
		_ent.HitWithVomit();
}

/**
 * Gets the entity's classname.
 * If the entity is valid, the entity's class is returned; otherwise, null is returned.
 * For example, "prop_dynamic" or "weapon_rifle_ak47"
 */
function VSLib::Entity::GetClassname()
{
	if (!IsEntityValid())
		return null;
	
	return _ent.GetClassname();
}

/**
 * Sets the entity's global name.
 * If the entity is valid, the global name of the entity is set. The global name
 * of the entity corresponds to the "Global Name" field of the entity in the Property
 * Window in Hammer. Global entities may carry over onto future maps in a campaign,
 * so setting an entity's global name may be helpful in certain situations.
 */
function VSLib::Entity::SetGlobalName(name)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	name = name.tostring();
	
	_ent.__KeyValueFromString("globalname", name);
}

/**
 * Sets the entity's parent name.
 * If the entity is valid, the name of the entity is set. Note that this function does
 * NOT parent an entity; only the parent's targetname is set. This is equivalent to setting
 * the "Parent" field in Hammer.
 */
function VSLib::Entity::SetParentName(name)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	name = name.tostring();
	
	_ent.__KeyValueFromString("parentname", name);
}

/**
 * Sets the entity's speed.
 * If the entity is valid, the speed of the entity is set.
 * The speed cannot be set for player entities.
 */
function VSLib::Entity::SetSpeed(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	_ent.__KeyValueFromString("speed", value);
}

/**
 * Sets the entity's render effect.
 * The entity can be given a special effect (like fading, pulsing, etc).
 * If the entity is valid, the render effect is set. Here are the possible values:
 * 	0 -> No effect
 * 	1 -> Slow pulse
 * 	2 -> Fast pulse
 * 	3 -> Slow, wide pulse
 * 	4 -> Fast, wide pulse
 * 	5 -> Slow fade
 * 	6 -> Fast fade
 * 	7 -> Slow solidify (no you can't make ice)
 * 	8 -> Fast solidify
 * 	9 -> Slow strobe
 * 	10 -> Fast strobe
 * 	11 -> Strobe even faster
 * 	12 -> Slow flicker
 * 	13 -> Fast flicker
 * 	14 -> No dissipation
 * 	15 -> Distort entity
 * 	16 -> Hologram effect
 * 	17 -> Super scale; become huge
 * 	18 -> Glowing shell
 * 	19 -> Clamp sprite (prevents sprites from getting smaller when increasing disatance)
 * 	20 -> Rain effect (for environments)
 * 	21 -> Snow effect (for environments again)
 * 	22 -> Valve's experimental spotlight effect
 * 	23 -> Ragdoll effect
 * 	24 -> Pulse faster and wider (dunno why Valve put the value all the way down here)
 */
function VSLib::Entity::SetRenderEffects(value)
{
	if (_ent == null)
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
		
	value = value.tointeger();
	
	_ent.__KeyValueFromInt("renderfx", value);
}

/**
 * Sets the entity's render mode.
 * The render mode allows you to change how an entity should render. With specific values,
 * you can make entities invisible, change the object's buffer checks, blending, and more.
 * Here are the possible values:
 * 	0 -> Normal (no render mode modification)
 * 	1 -> Transcolor
 * 	2 -> Transtexture
 * 	3 -> Glow
 * 	4 -> Transalpha
 * 	5 -> Transadd
 * 	6 -> Environmental
 * 	7 -> Transadd Frame Blend
 * 	8 -> Transalpha add
 * 	9 -> World glow
 * 	10 -> Rend None
 */
function VSLib::Entity::SetRenderMode(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tointeger();
	
	_ent.__KeyValueFromInt("rendermode", value);
}

/**
 * Sets the entity's next Think time.
 * To be totally honest, I can't think of a reason for this function.
 * Provided just for those who may need it. \todo @TODO This may or may not
 * work, provided that the KV field is FIELD_TICK.
 */
function VSLib::Entity::SetNextThinkTime(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tointeger();
	
	_ent.__KeyValueFromInt("nextthink", value);
}

/**
 * Sets the entity's secondary effects.
 * Depending on the value, effects like light projection (i.e. flashlight)
 * can be enabled and disabled (for player entities). See Player class
 * for a function already made for that purpose.
 */
function VSLib::Entity::SetEffects(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tointeger();
	
	_ent.__KeyValueFromInt("effects", value);
}

/**
 * Sets the entity's render color.
 * Changes the overall color of the entity. For example, a value of (255, 0, 0, 255)
 * will give the entity a red hue. The alpha property really doesn't affect much unless
 * the render mode also changes. If you are looking to change the visibility, use
 * Entity.SetVisible() instead.
 */
function VSLib::Entity::SetColor(red, green, blue, alpha)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.__KeyValueFromString("rendercolor", red + " " + green + " " + blue + " " + alpha);
}

/**
 * Changes the entity's visibility.
 * If the visible parameter is true, the entity will become visible to all players.
 * If the visible paramater is false, the entity will become invisible to all players.
 */
function VSLib::Entity::SetVisible(canSee)
{
	local visible = (canSee.tointeger() > 0) ? true : false;
	
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (visible)
	{
		SetRenderMode(0); // Render mode: normal
		SetColor(255, 255, 255, 255); // Default hue.
	}
	else
	{
		SetRenderMode(1); // Render mode: transcolor
		SetColor(0, 0, 0, 0); // zero all values for color
	}
}

/**
 * Sets the entity's model index.
 * If the entity has more than one model associated with it (i.e. it has more than one
 * model index), then you can instantly change the model index with this function. This
 * function is useful for those who would like to have an entity have more than one model.
 * \todo @TODO verify that global keyfields can be modified with Valve's __KeyValueFromInt()
 */
function VSLib::Entity::SetModelIndex(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
		
	value = value.tointeger();
	
	_ent.__KeyValueFromInt("modelindex", value);
}

/**
 * Sets the entity's response context.
 * This function deals more with AI criteria sets and dispatching responses.
 * Practically useless for what we do, since the entity would need to be
 * re-activated and there's no plausible way to do that via VScripts.
 * If your mod needs to deal with m_iszResponseContext, use another scripting
 * engine like HammerCode or SourceMod.
 */
function VSLib::Entity::SetResponseContext(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	
	_ent.__KeyValueFromString("ResponseContext", value);
}

/**
 * Sets the m_target netprop of the entity.
 * Provided for completeness, but the function doesn't seem to do much on L4D2.
 * The prop has taken a back seat to m_iName from the looks of it.
 */
function VSLib::Entity::SetTarget(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	
	_ent.__KeyValueFromString("target", value);
}

/**
 * Sets the damage filter name of the entity.
 * Provided for completeness. This function sets the m_iszDamageFilterName KV,
 * which is later used in InputSetDamageFilter() in the c++ backend to
 * find the name stored in m_iszDamageFilterName to set m_hDamageFilter, which is
 * later used in PassesDamageFilter() to see if the CTakeDamageInfo object passes
 * the damage filter. In simple terms, this function is as good as useless for us.
 */
function VSLib::Entity::SetDamageFilter(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	
	_ent.__KeyValueFromString("damagefilter", value);
}

/**
 * Sets the shadow cast distance.
 * I honestly cannot think of any good use for this, unless you want to change the
 * shadow distance over time or something. Granted, it may not even work. Provided
 * for completeness.
 */
function VSLib::Entity::SetShadowCastDistance(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	
	_ent.__KeyValueFromString("shadowcastdist", value);
}

/**
 * Applies an absolute velocity impulse to an entity.
 * An impulse is given to the entity. In this function, by setting a value negative
 * to an entity's trajectory, the entity may or may not change paths depending on the
 * scalar value of the vector. All we are doing is "pushing" an entity in the given
 * direction. The higher the dimensional value, the stronger the "push" (to put it
 * very simply). There are a lot of uses for this function.
 */
function VSLib::Entity::Push(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.ApplyAbsVelocityImpulse(vec);
}

/**
 * Applies an angular velocity impulse to an entity.
 * Using this function, we can make physics props spin around or rotate.
 */
function VSLib::Entity::Spin(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.ApplyLocalAngularVelocityImpulse(vec);
}

/**
 * Sets the entity's gravity.
 */
function VSLib::Entity::SetGravity(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	
	_ent.__KeyValueFromString("gravity", value);
}

/**
 * Sets the entity's friction.
 */
function VSLib::Entity::SetFriction(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	value = value.tostring();
	
	_ent.__KeyValueFromString("friction", value);
}

/**
 * Returns the entity's current velocity vector.
 */
function VSLib::Entity::GetVelocity()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return _ent.GetVelocity();
}

/**
 * Sets the entity's current velocity vector.
 * This can be used to force an entity to move in a particular direction.
 */
function VSLib::Entity::SetVelocity(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.SetVelocity(vec);
}

/**
 * Sets the entity's current velocity vector KV.
 */
function VSLib::Entity::SetVelocityKV(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	SetKeyValue("velocity", vec);
}

/**
 * Sets the entity's current base velocity vector KV.
 */
function VSLib::Entity::SetBaseVelocity(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	SetKeyValue("basevelocity", vec);
}

/**
 * Sets the entity's current angular velocity vector KV.
 */
function VSLib::Entity::SetAngularVelocity(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	SetKeyValue("avelocity", vec);
}

/**
 * Sets the entity's current water level.
 */
function VSLib::Entity::SetAngularVelocity(lvl)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	SetKeyValue("waterlevel", lvl.tostring());
}

/**
 * Sets the entity's spawn flags.
 */
function VSLib::Entity::SetSpawnFlags(flags)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	SetKeyValue("spawnflags", flags.tostring());
}

/**
 * Gets the direction that the entity's eyes are facing.
 */
function VSLib::Entity::GetEyeAngles()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (!("EyeAngles" in _ent))
	{
		printl("VSLib Warning: Entity " + _idx + " does not have Eye Angles.");
		return;
	}
	
	return _ent.EyeAngles();
}

/**
 * Returns the base entity (in case you need to access Valve's CBaseEntity/CBaseAnimating functions manually)
 */
function VSLib::Entity::GetBaseEntity()
{
	return _ent;
}

/**
 * Returns the initial index or name passed to the entity.
 */
function VSLib::Entity::GetIndex()
{
	return _idx;
}

/**
 * Gets the entity's current location.
 */
function VSLib::Entity::GetLocation()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return _ent.GetOrigin();
}

/**
 * Sets the entity's current location vector (i.e. teleports the entity).
 */
function VSLib::Entity::SetLocation(vec)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.SetOrigin(vec);
}

/**
 * Sets the entity's current position (basically calls SetLocation() internally).
 */
function VSLib::Entity::SetPosition(x, y, z)
{
	SetLocation( Vector(x, y, z) );
}

/**
 * Gets the entity's current position (basically calls GetLocation() internally).
 */
function VSLib::Entity::GetPosition()
{
	return GetLocation();
}

/**
 * Does the same thing as SetLocation() in that it teleports the entity.
 * Internally the function just calls SetLocation(). Provided for simplicity,
 * as a lot of mappers seem to have difficulty understanding various terms.
 */
function VSLib::Entity::Teleport(vec)
{
	SetLocation(vec);
}

/**
 * Teleports the entity to another ::VSLib.Entity.
 */
function VSLib::Entity::TeleportTo(otherEntity)
{
	Teleport(otherEntity.GetLocation());
}

/**
 * Tries to guess what team the player might be on.
 * Returns either INFECTED or SURVIVORS.
 */
function VSLib::Entity::GetTeam()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (!("GetZombieType" in _ent))
		return UNKNOWN;
	else if (_ent.IsSurvivor() || _ent.GetZombieType() == SURVIVOR)
		return SURVIVORS;
	else if ((_ent.GetZombieType() > 0 && _ent.GetZombieType() < 9) || _ent.IsGhost() || _ent.GetClassname() == "infected")
		return INFECTED;
}

/**
 * Kills/removes the entity from the map.
 */
function VSLib::Entity::Kill()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.Kill();
}

/**
 * Returns the base angles.
 */
function VSLib::Entity::GetAngles()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return _ent.GetAngles();
}

/**
 * Sets the base angles.
 */
function VSLib::Entity::SetAngles(x, y, z)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return _ent.SetAngles(QAngle(x,y,z));
}

/**
 * Kills/removes the entity and associated entities from the map.
 */
function VSLib::Entity::KillHierarchy()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	DoEntFire("!self", "KillHierarchy", "", 0, null, _ent);
}

/**
 * Attempts to "Use" or pick up another entity.
 */
function VSLib::Entity::UseOther(otherEntity)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	DoEntFire("!self", "Use", "", 0, _ent, otherEntity.GetBaseEntity());
}

/**
 * Attempts to be "used" or picked up BY another entity.
 */
function VSLib::Entity::UsedByOther(otherEntity)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	DoEntFire("!self", "Use", "", 0, otherEntity.GetBaseEntity(), _ent);
}

/**
 * Set the alpha value of the entity.
 * Only seems to work for players.
 */
function VSLib::Entity::SetAlpha(value)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	DoEntFire("!self", "Alpha", value.tostring(), 0, null, _ent);
}

/**
 * Inputs a color to an entity. This is an alternative to SetColor().
 */
function VSLib::Entity::InputColor(red, green, blue)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	DoEntFire("!self", "Color", red + " " + green + " " + blue, 0, null, _ent);
}

/**
 * Parents an entity to this entity.
 * In other words, attaches an entity to this entity. Cool for attaching bumper cars
 * or other objects to players. If teleportOther is TRUE, the other entity is teleported
 * to this entity. If it is FALSE, the entity is parented without teleporting.
 */
function VSLib::Entity::AttachOther(otherEntity, teleportOther)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	teleportOther = (teleportOther.tointeger() > 0) ? true : false;
	
	if (teleportOther)
		otherEntity.SetLocation(GetLocation());
	
	DoEntFire("!self", "SetParent", "!activator", 0, _ent, otherEntity.GetBaseEntity());
}

/**
 * Attaches another entity to a specific point.
 * Call this function after AttachOther() to parent at a specific attachment point. For example,
 * if attachment equals "rhand", the object will be attached to the player's or entity's
 * right hand. "forward" to attach to head etc. Search for player or entity attachment points
 * on Google (i.e. "L4D2 survivor attachment points" or something along those lines).
 * If ShouldMaintainOffset is true, then the initial distance between the object is maintained,
 * and the angles usually point in the direction of the parent.
 */
function VSLib::Entity::SetAttachmentPoint(otherEntity, attachment, bShouldMaintainOffset)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	attachment = attachment.tostring();
	bShouldMaintainOffset = (bShouldMaintainOffset.tointeger() > 0) ? true : false;
	
	if (bShouldMaintainOffset)
		DoEntFire("!self", "SetParentAttachmentMaintainOffset", attachment, 0, _ent, otherEntity.GetBaseEntity());
	else
		DoEntFire("!self", "SetParentAttachment", attachment, 0, _ent, otherEntity.GetBaseEntity());
}

/**
 * Remove the parenting.
 */
function VSLib::Entity::RemoveAttached(otherEntity)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	DoEntFire("!self", "ClearParent", "", 0, _ent, otherEntity.GetBaseEntity());
}

/**
 * Estimates the eye position.
 */
function VSLib::Entity::GetEyePosition()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	//// 5/21 EMS update
	// If the entity has an eyeposition function, return it.
	if ("EyePosition" in _ent)
		return _ent.EyePosition();
	
	// if it's not a player, it probably doesn't have eyes...
	return GetLocation();
}

/**
 * Gets the entity that this entity is pointing at, or null if this entity is not pointing at a valid entity.
 * This is useful for things like detecting what entity a player may be looking at.
 */
function VSLib::Entity::GetLookingEntity()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (!("EyeAngles" in _ent))
	{
		printl("VSLib Warning: Entity " + _idx + " does not have Eye Angles.");
		return;
	}
	
	local startPt = GetEyePosition();
	local endPt = startPt + _ent.EyeAngles().Forward().Scale(999999);
	
	local m_trace = { start = startPt, end = endPt, ignore = _ent };
	TraceLine(m_trace);
	
	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == _ent)
		return null;
	
	if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
		return null;
	
	local vsEnt = ::VSLib.Entity(m_trace.enthit);
	if (vsEnt.IsPlayer())
		return ::VSLib.Player(vsEnt);
	return vsEnt;
}

/**
 * Returns the numerical index of the entity.
 * Because Valve didn't provide a function to convert a base entity back to an index,
 * we go the long way around by using an entity loop.
 */
function VSLib::Entity::GetBaseIndex()
{
	if (_ent == null)
	{
		printl("VSLib Warning: Entity is invalid.");
		return -1;
	}
	
	// After the 5/21 EMS update, we now have GetEntityIndex()
	return _ent.GetEntityIndex();
	
	// No longer needed
	/*
	for (local i = 1; i <= 2048; i++)	
		if (_ent == Ent(i))
			return i;
	
	return -1;
	*/
}

/**
 * Kills the entity after the specified delay in seconds; fractions may be used if needed (e.g. 1.5 seconds).
 */
function VSLib::Entity::KillDelayed(seconds)
{
	if (_ent == null)
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	seconds = seconds.tofloat();
	
	DoEntFire("!self", "Kill", "", seconds, null, _ent);
}

/**
 * Returns a vector position of where the entity is looking.
 */
function VSLib::Entity::GetLookingLocation()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	if (!("EyeAngles" in _ent))
	{
		printl("VSLib Warning: Entity " + _idx + " does not have Eye Angles.");
		return;
	}
	
	local startPt = GetEyePosition();
	local endPt = startPt + _ent.EyeAngles().Forward().Scale(999999);
	
	local m_trace = { start = startPt, end = endPt, ignore = _ent, mask = g_MapScript.TRACE_MASK_SHOT };
	TraceLine(m_trace);
	
	if (!m_trace.hit || m_trace.enthit == _ent)
		return null;
	
	return m_trace.pos;
}

/**
 * Ingites the entity for the specified time. Fractions can be used (e.g. 1.5 seconds).
 */
function VSLib::Entity::Ignite(time)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	time = time.tostring();
	
	HurtTime(1, 2056, 0.3, time);
	DoEntFire("!self", "IgniteLifetime", time, 0, null, _ent);
}

/**
 * Attaches a particle to this entity.
 * E.g. "gas_fireball" or "elevatorsparks". Internally spawns an
 * info_particle_system, so all effects that can be shown with that
 * entity can be shown with this function. This function will return the
 * particle system that was created, so if you need to attach it to a
 * specific attachment point or whatever, you can.
 */
function VSLib::Entity::AttachParticle(particleName, duration)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	particleName = particleName.tostring();
	duration = duration.tofloat();
	
	local particle = g_ModeScript.CreateSingleSimpleEntityFromTable({ classname = "info_particle_system", targetname = "vslib_tmp_" + UniqueString(), origin = GetLocation(), angles = QAngle(0,0,0), start_active = true, effect_name = particleName });
	
	if (!particle)
	{
		Msg("Warning: Could not create info_particle_system entity.");
		return;
	}
	
	DoEntFire("!self", "Start", "", 0, null, particle);
	
	local vsParticle = ::VSLib.Entity(particle);
	
	vsParticle.KillDelayed(duration);
	AttachOther(vsParticle, true);
	
	return vsParticle;
}

/**
 * Returns true if the entity is a player.
 */
function VSLib::Entity::IsPlayer()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	if ("IsPlayer" in _ent)
		return _ent.IsPlayer();
	
	return "player" == _ent.GetClassname().tolower();
}

/**
 * Returns true if the entity is alive.
 * For players, once a player dies, it still reports alive. Use Player class for IsAlive().
 */
function VSLib::Entity::IsAlive()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return GetHealth() > 0;
}

/**
 * Returns the name of the entity.
 */
function VSLib::Entity::GetName()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetName();
}

/**
 * Returns the distance (in units) to the ground from the entity's origin.
 */
function VSLib::Entity::GetDistanceToGround()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	local startPt = GetLocation();
	local endPt = startPt + Vector(0, 0, -9999999);
	
	local m_trace = { start = startPt, end = endPt, ignore = _ent, mask = g_MapScript.TRACE_MASK_SHOT };
	TraceLine(m_trace);
	
	if (m_trace.enthit == _ent || !m_trace.hit)
		return 0.0;
	
	return ::VSLib.Utils.CalculateDistance(startPt, m_trace.pos);
}

/**
 * Returns true if the entity is in the air.
 */
function VSLib::Entity::IsEntityInAir()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return GetDistanceToGround() > 5.0;
}

/**
 * The "give" concommand.
 *
 * @param str What to give the entity (for example, "health")
 */
function VSLib::Entity::Give(str)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	_ent.GiveItem(str);
}

/**
 * Returns the entity's button mask
 */
function VSLib::Entity::GetPressedButtons()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask();
}

/**
 * Returns if the client is pressing the specified button
 */
function VSLib::Entity::IsPressingButton(btn)
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & btn;
}

/**
 * Returns true if this player is currently firing a weapon (either a gun, bat, etc).
 * Note that it doesn't check if the gun has any ammo (just checks for key press).
 */
function VSLib::Entity::IsPressingAttack()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 0);
}

/**
 * Returns true if this player is jumping (or pressing the space bar button for example).
 */
function VSLib::Entity::IsPressingJump()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 1);
}

/**
 * Returns true if this player is ducking (or pressing the CTRL key for example).
 */
function VSLib::Entity::IsPressingDuck()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 2);
}

/**
 * Returns true if this player is pressing forward (or pressing the W key for example).
 */
function VSLib::Entity::IsPressingForward()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 3);
}

/**
 * Returns true if this player is pressing backward (or pressing the S key for example).
 */
function VSLib::Entity::IsPressingBackward()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 4);
}

/**
 * Returns true if this player is pressing the USE key (or pressing the E key for example).
 */
function VSLib::Entity::IsPressingUse()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 5);
}

/**
 * Returns true if this player is pressing the Left key (or pressing the A key for example).
 */
function VSLib::Entity::IsPressingLeft()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 9);
}

/**
 * Returns true if this player is pressing the Right key (or pressing the D key for example).
 */
function VSLib::Entity::IsPressingRight()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 10);
}

/**
 * Returns true if this player is pressing the shove key (or pressing right-click for example).
 */
function VSLib::Entity::IsPressingShove()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 11);
}

/**
 * Returns true if this player is pressing the reload key (or pressing the R key for example).
 */
function VSLib::Entity::IsPressingReload()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 13);
}

/**
 * Returns true if this player is pressing the walk key (or pressing the shift key for example).
 */
function VSLib::Entity::IsPressingWalk()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 18);
}

/**
 * Returns true if this player is pressing the zoom key.
 */
function VSLib::Entity::IsPressingZoom()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return false;
	}
	
	return _ent.GetButtonMask() & (1 << 19);
}

/**
 * Returns the entity's owner
 */
function VSLib::Entity::GetOwnerEntity()
{
	if (!IsEntityValid())
	{
		printl("VSLib Warning: Entity " + _idx + " is invalid.");
		return;
	}
	
	return _ent.GetOwnerEntity();
}






/**
 * Processes damage data associated with ::VSLib.
 */
function AllowTakeDamage(damageTable)
{
	// Process triggered hurts
	if (damageTable.Attacker == ::VSLib.EntData._lastHurt)
	{
		if (damageTable.Victim == ::VSLib.EntData._hurtIntent)
		{
			damageTable.DamageDone = ::VSLib.EntData._hurtDmg;
			return true;
		}
		
		return false;
	}
	
	// Process continuous hurts
	foreach (idx, point_hurt in ::VSLib.EntData._continuousHurt)
	{
		if (damageTable.Attacker == point_hurt)
		{
			if (damageTable.Victim == ::VSLib.EntData._continuousHurtIntent[idx])
			{
				damageTable.DamageDone = ::VSLib.EntData._continuousHurtDmg[idx];
				return true;
			}
			
			return false;
		}
	}
	
	if (!::VSLib.EntData._forcedHurt)
	{
		// Process hooks
		if ("EasyLogic" in VSLib)
		{
			if (damageTable.Victim != null)
			{
				local name = damageTable.Victim.GetClassname();
				if (name in ::VSLib.EasyLogic.OnDamage)
				{
					::VSLib.EntData._forcedHurt = false;
					
					local victim = ::VSLib.Player(damageTable.Victim);
					local attacker = ::VSLib.Player(damageTable.Attacker);
				
					local damagesave = damageTable.DamageDone;
					damageTable.DamageDone = ::VSLib.EasyLogic.OnDamage[name](victim, attacker, damageTable.DamageDone, damageTable);
					
					if (damageTable.DamageDone == null)
						damageTable.DamageDone = damagesave;
					else if (damageTable.DamageDone <= 0)
						return false;
					
					return true;
				}
			}
			
			foreach (func in ::VSLib.EasyLogic.OnTakeDamage)
			{
				if (func(damageTable) == false)
					return false;
			}
		}
	}
	
	// Reset force for next cycle
	::VSLib.EntData._forcedHurt = false;
	
	return true;
}




// Add a weak reference to the global table.
::Entity <- ::VSLib.Entity.weakref();