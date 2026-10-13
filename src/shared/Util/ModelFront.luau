--!strict
-- Which way a pet or egg model faces. Pack pets mark their front with a
-- "FaceDecal" decal; models without one are taken to face -Z. Used by the
-- client previews (UI/AssetModels) and by the pets on plot platforms.

local ModelFront = {}

-- The direction a model faces, in its pivot's space and flattened to the
-- ground plane.
function ModelFront.LocalFront(model: Model): Vector3
	local pivot = model:GetPivot()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Decal") and descendant.Name == "FaceDecal" then
			local part = descendant.Parent
			if part and part:IsA("BasePart") then
				local world = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(descendant.Face))
				local flat = pivot:VectorToObjectSpace(world) * Vector3.new(1, 0, 1)
				if flat.Magnitude > 0.01 then
					return flat.Unit
				end
			end
		end
	end
	return Vector3.new(0, 0, -1)
end

-- Rotation that turns a model's own front into -Z (CFrame.LookVector).
function ModelFront.Correction(model: Model): CFrame
	return CFrame.lookAt(Vector3.zero, ModelFront.LocalFront(model)):Inverse()
end

return ModelFront
