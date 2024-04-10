exports('NativeCreateComposite', (compositeHash, x, y, z, heading, onGround, unk) => {
    let buffer = new ArrayBuffer(4 * 8);
    let view = new DataView(buffer);

    let composite = Citizen.invokeNative("0x5B4BBE80AD5972DC", compositeHash, x, y, z, heading, onGround/* ? 0 : 2*/, view, unk);

    let out = new Int32Array(buffer);

    return composite;
});

/*exports('NativeCreateComposite', (compositeHash, x, y, z, heading, onGround) => {
    let buffer = new ArrayBuffer(4 * 8);
    let view = new DataView(buffer);

    let composite = Citizen.invokeNative("0x5B4BBE80AD5972DC", compositeHash, x, y, z, heading, onGround ? 0 : 2, view, -1);

    let out = new Int32Array(buffer);

    return composite;
});*/

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