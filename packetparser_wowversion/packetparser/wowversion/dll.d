module packetparser.wowversion.dll;

import core.runtime;
import std.c.windows.windows;
HINSTANCE g_hInst;

extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
	switch (ulReason)
	{
		case DLL_PROCESS_ATTACH:
			Runtime.initialize();
			break;
		case DLL_PROCESS_DETACH:
			Runtime.terminate();
			break;
		case DLL_THREAD_ATTACH:
			return false;
		case DLL_THREAD_DETACH:
			return false;
        default:
	}
	g_hInst = hInstance;
	return true;
}