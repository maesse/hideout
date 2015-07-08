modifier_hider_aura = class({})
--------------------------------------------------------------------------------

function modifier_hider_aura:OnCreated( kv )
  print("modifier_hider_aura - onCreated")
	self.armor_bonus = self:GetAbility():GetSpecialValueFor( "armor_bonus" )
	self.speed_bonus = self:GetAbility():GetSpecialValueFor( "speed_bonus" )
	if IsServer() then
		local nFXIndex = ParticleManager:CreateParticle( "particles/units/heroes/hero_sven/sven_warcry_buff.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
		ParticleManager:SetParticleControlEnt( nFXIndex, 2, self:GetCaster(), PATTACH_POINT_FOLLOW, "attach_head", self:GetCaster():GetOrigin(), true )
		self:AddParticle( nFXIndex, false, false, -1, false, true )
	end
end

--------------------------------------------------------------------------------

function modifier_hider_aura:OnRefresh( kv )
	self.armor_bonus = self:GetAbility():GetSpecialValueFor( "armor_bonus" )
	self.speed_bonus = self:GetAbility():GetSpecialValueFor( "speed_bonus" )
end

--------------------------------------------------------------------------------

function modifier_hider_aura:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}

	return funcs
end

--------------------------------------------------------------------------------

function modifier_hider_aura:GetActivityTranslationModifiers( params )
  print("HUH? - GetActivityTranslationModifiers?")
	if self:GetParent() == self:GetCaster() then
		return "sven_warcry"
	end

	return 0
end

--------------------------------------------------------------------------------

function modifier_hider_aura:GetModifierMoveSpeedBonus_Percentage( params )
	return self.speed_bonus
end

--------------------------------------------------------------------------------

function modifier_hider_aura:GetModifierPhysicalArmorBonus( params )
	return self.armor_bonus
end

--------------------------------------------------------------------------------