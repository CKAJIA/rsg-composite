exports('NativeCreateComposite', (compositeHash, x, y, z, heading, onGround, unk) => {
    let buffer = new ArrayBuffer(4 * 8);
    let view = new DataView(buffer);

    let composite = Citizen.invokeNative("0x5B4BBE80AD5972DC", compositeHash, x, y, z, heading, onGround, view, unk);

    let out = new Int32Array(buffer);

    return composite;
});

/*
exports('NativeCreateComposite', (compositeHash, x, y, z, heading, groundSetting, variant) => {
    const buffer = new ArrayBuffer(4 * 8);
    const view = new DataView(buffer);
    
	const compositeId = Citizen.invokeNative("0x5B4BBE80AD5972DC", compositeHash, x, y, z, heading, groundSetting, view, variant);
    const outSlot = view.getInt32(0, true);  // <- SLOT 0-3 или -1
    
    return [compositeId, outSlot];  // outSlot = твой outValue!
});
//ПРИМЕР
//local result = exports["rsg-composite"]:NativeCreateComposite(compositeHash, herbCoords[index].x, herbCoords[index].y, herbCoords[index].z, Heading, onGround, -1)
//local compositeId = result[1]
//local outSlot = result[2]
*/

exports('NativeGetGroundZFor3dCoord', (x, y, z) => {
    let buffer = new ArrayBuffer(4 * 8);
    let view = new DataView(buffer);

    Citizen.invokeNative("0x24FA4267BB8D2431", x, y, z, view, false, Citizen.returnResultAnyway());
    let out = new Int32Array(buffer);

    return out;
});

exports('NativeGetCompositeEntities', (composite) => {
    let buffer = new ArrayBuffer(256);
    let view = new DataView(buffer);

    let size = Citizen.invokeNative("0x96C6ED22FB742C3E", composite, view);
    let out = new Int32Array(buffer);
	//console.log(size);
    return [size, out];
});

exports('DataViewNativeGetEventData', (eventGroup, index, argStructSize) => {

    let buffer = new ArrayBuffer(256);
    let view = new DataView(buffer);
    // dataView.setInt32(0, 3);
    // dataView.setInt32(3, );

    Citizen.invokeNative("0x57EC5FA4D4D6AFCA", eventGroup, index, view, argStructSize, Citizen.returnResultAnyway());
    let out = new Int32Array(buffer);

    // console.log(out);
    return out;
});

exports('DataViewNativeGetEventDataT', (eventGroup, index, argStructSize) => {

    let buffer = new ArrayBuffer(8 * argStructSize);
    let view = new DataView(buffer);
    // dataView.setInt32(0, 3);
    // dataView.setInt32(3, );

    Citizen.invokeNative("0x57EC5FA4D4D6AFCA", eventGroup, index, view, argStructSize, Citizen.returnResultAnyway());
    let out = new Int32Array(buffer);

    // console.log(out);
    return out;
});


exports('showAdvancedRightNotification', (text, dict, icon, text_color, duration, quality, pick) => {
	const _text = CreateVarString(10, "LITERAL_STRING", text);
	const _dict = CreateVarString(10, "LITERAL_STRING", dict);
	const sdict = CreateVarString(10, "LITERAL_STRING", "Transaction_Feed_Sounds");
	let sound = CreateVarString(10, "LITERAL_STRING", "Transaction_Positive");
	if (pick === 0) {
		sound = CreateVarString(10, "LITERAL_STRING", "Transaction_Negative");
	}

	const struct1 = new DataView(new ArrayBuffer(48));
	struct1.setInt32(0, duration, true);
	struct1.setBigInt64(8, BigInt(sdict), true);
	struct1.setBigInt64(16, BigInt(sound), true);


	const struct2 = new DataView(new ArrayBuffer(76));
	struct2.setBigInt64(8, BigInt(_text), true);
	struct2.setBigInt64(16, BigInt(_dict), true);
	struct2.setBigInt64(24, BigInt(GetHashKey(icon)), true);
	struct2.setBigInt64(40, BigInt(GetHashKey(text_color || "COLOR_WHITE")), true);
	struct2.setInt32(48, quality, true); // quality stars or something works without icon

	Citizen.invokeNative("0xB249EBCB30DD88E0", struct1, struct2, 1);
});