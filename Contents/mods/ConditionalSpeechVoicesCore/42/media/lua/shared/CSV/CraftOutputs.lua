-- Exact Base handcraft outputs. Several unrelated recipes use the Tools category.
local recipes={
 TraitGlasswork={
  MakeGlassJar='JarCrafted', MakeGlassBottle='BottleCrafted', MakeDrinkingGlass='DrinkingGlass',
  MakeChampagneGlass='GlassChampagne', MakeWineGlass='GlassWine', MakeLanternGlass='LanternGlass',
  MakeGlassPanel='GlassPanel',
 },
 TraitForgeWork={
  Forge_Nails='Nails', Forge_Nails_From_Piece='Nails', Forge_Nails_From_Wire='Nails',
  Forge_Hinge='Hinge', Forge_Tongs='Tongs', Forge_Masons_Chisel='MasonsChisel',
  Forge_Carpentry_Chisel='CarpentryChisel', Forge_Metalworking_Chisel='MetalworkingChisel',
 },
 TraitMasonry={
  Make_Stone_Block_from_Stone='StoneBlock', Make_Small_Stone_Wheel='StoneWheelSmall',
  Make_Stone_Wheel='StoneWheel', Make_Stone_Anvil='StoneAnvil',
 },
 TraitWhittling={
  CarveWoodenSpoon='WoodenSpoon', CarveWoodenFork='WoodenFork', CarveWoodenSpade='SpadeWood',
  CarveBucket='BucketCarved', CarveGoblets='Goblet_Wood', MakeCrudeWoodenTongs='CrudeWoodenTongs',
  CarveSmallHandle='SmallHandle', Carve2SmallHandles='SmallHandle', Carve4SmallHandles='SmallHandle',
  Carve8SmallHandles='SmallHandle', CarveSmallHandlesFromPlank='SmallHandle',
  CarveMediumHandle='Handle', CarveMediumHandlesFromPlank='Handle', CarveLongHandle='LongHandle',
 },
}

local M={}
function M.find(name)
 if type(name)~='string' then return end
 name=name:match('^Base%.(.+)$') or name
 for group,outputs in pairs(recipes)do
  if outputs[name] then return group,'Base.'..outputs[name] end
 end
end
return M
