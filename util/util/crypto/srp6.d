/+
 + This protocol implements SecureRemotePassword mechanism
 + see http://tools.ietf.org/html/rfc5054
 +/
module util.crypto.srp6;

import std.digest.sha;
import std.system;
import std.conv : to;

import std.array;
import std.algorithm;
import std.range;
import std.typecons : tuple, Tuple;

import util.crypto.big_num;

/++
+ Provides calculations for srp6a protocol
+ IOENDIAN specifies if ubyte[] numeric data input and output is littleEndian or bigEndian
+ littleEndian is custom Blizzard's extension
+/
final class SRP(Endian IOENDIAN)
{
    protected
    {
        BigNumber N; // "prime"
        BigNumber g; // "generator"
        BigNumber k;
    }

    enum IOEndian = IOENDIAN;

    ubyte[] Nbytes()
    {
        return N.toByteArray(IOEndian);
    }

    ubyte[] gbytes()
    {
        return g.toByteArray(IOEndian);
    }

    /++
    + Needs to be initialized with BIGENDIAN prime N and generator g
    +/
    this(in ubyte[] nbytes, in ubyte[] gbytes)
    {
        this.N = BigNumber(nbytes, Endian.bigEndian);
        this.g = BigNumber(gbytes, Endian.bigEndian);
        auto Ng = appender!(ubyte[]);
        Ng.put(N.toByteArray(Endian.bigEndian));
        Ng.put(pad(g.toByteArray(Endian.bigEndian)));

        // k = SHA1(N | PAD(g))
        k = BigNumber(sha1Of(Ng.data()), Endian.bigEndian);
    }

    /++
    + Needs to be initialized with BIGENDIAN prime N and generator g and custom k
    +/
    this(in ubyte[] nbytes, in ubyte[] gbytes, in ubyte[] kbytes)
    {
        this.N = BigNumber(nbytes, Endian.bigEndian);
        this.g = BigNumber(gbytes, Endian.bigEndian);
        this.k = BigNumber(kbytes, Endian.bigEndian);
    }

    /++
    + Calculates data for clientside authentication
    + Returns ClientProof object
    +/
    immutable(ClientProof) clientChallange(in ubyte[] username, in ubyte[] password, in ubyte[] salt, in ubyte[] Bbytes, in ubyte[] abytes, in ubyte[] Abytes) const
    {
        auto u = calculate_u(Abytes, Bbytes);
        auto x = calculate_x(salt, username, password);
        auto v = calculate_v(x);
        auto A = BigNumber(Abytes, IOEndian);
        auto B = BigNumber(Bbytes, IOEndian);
        auto a = BigNumber(abytes, IOEndian);

        // Secret = (B - (k * v)) ^ (a + (u * x)) % N
        BigNumber S = (B - (k * v)).modExp((a + (u * x)), N);

        auto K = interleave(S.toByteArray(IOEndian));

        auto M1 = calculateM1(username, salt, Abytes, Bbytes, K);

        auto M2 = calculateM2(Abytes, M1, K);

        return new immutable(ClientProof)(K, M1, M2);
    }

    /++
    + Calculates data for serverside authentication
    + Returns ServerProof object
    +/
    immutable(ServerProof) serverChallange(in ubyte[] username, in ubyte[] salt, in ubyte[] vbytes, in ubyte[] Abytes, in ubyte[] bbytes) const
    {
        auto v = BigNumber(vbytes, IOEndian);

        auto b = BigNumber(bbytes, IOEndian);

        BigNumber B = calculateB(v, b);

        auto Bbytes = B.toByteArray(IOEndian);

        auto A = BigNumber(Abytes, IOEndian);
        auto u = calculate_u(Abytes, Bbytes);

        // S = (A * v^u) ^ b % N
        BigNumber S = (A * v.modExp(u, N)).modExp(b, N);

        auto K = interleave(S.toByteArray(IOEndian));

        auto M1 = calculateM1(username, salt, Abytes, Bbytes, K);

        auto M2 = calculateM2(Abytes, M1, K);

        version(unittest)
            return new immutable(ServerProof)(Bbytes, M1, M2, K, S.toByteArray(IOEndian));
        else
            return new immutable(ServerProof)(Bbytes, M1, M2, K);
    }

    /// A = g^a mod N - client's public key
    ubyte[] calculateA(in ubyte[] abytes) const
    {
        BigNumber a = BigNumber(abytes, IOEndian);
        return g.modExp(a, N).toByteArray(IOEndian);
    }

    // v = (g^x) % N
    BigNumber calculate_v(in BigNumber x) const
    {
        return g.modExp(x, N);
    }

    // B = (k*v + g^b) % N
    BigNumber calculateB(in BigNumber v, in BigNumber b) const
    {
        return (k*v + g.modExp(b, N)) % N;
    }

    // B = (k*v + g^b) % N
    BigNumber calculateB(in ubyte[] vbytes, in ubyte[] bbytes) const
    {
        auto v = BigNumber(vbytes, IOEndian);

        auto b = BigNumber(bbytes, IOEndian);

        return calculateB(v, b);
    }

protected:
    // as defined by the rfc
    ubyte[] pad(in ubyte[] bytes) const
    {
        assert(N.byteArrayLength >= bytes.length);
        return new ubyte[N.byteArrayLength - bytes.length] ~ bytes;
    }

    // u = SHA1(PAD(A) | PAD(B))
    BigNumber calculate_u(in ubyte[] A, in ubyte[] B) const
    {
        auto uBytes = appender!(ubyte[]);
        uBytes.put(pad(A));
        uBytes.put(pad(B));

        return BigNumber(sha1Of(uBytes.data()), IOEndian);
    }

    // x = SHA1(salt | SHA1(username | ":" | password)
    BigNumber calculate_x(in ubyte[] salt, in ubyte[] username, in ubyte[] password) const
    {
        auto ucp = appender!(ubyte[]);
        ucp.put(username);
        ucp.put(':');
        ucp.put(password);

        return BigNumber(sha1Of(salt ~ (sha1Of(ucp.data()))), IOEndian);
    }

    // M = SHA1(SHA1(N) XOR SHA1(g) | SHA1(username) | s | A | B | K)
    ubyte[] calculateM1(in ubyte[] username, in ubyte[] s, in ubyte[] A, in ubyte[] B, in ubyte[] K) const
    {
        auto mBytes = appender!(ubyte[])();

        foreach(a ; zip(sha1Of(N.toByteArray(IOEndian))[], sha1Of(g.toByteArray(IOEndian))[]))
        {
            mBytes.put((a[0] ^ a[1]).to!ubyte);
        }
        mBytes.put(sha1Of(username).dup);
        mBytes.put(s);
        mBytes.put(A);
        mBytes.put(B);
        mBytes.put(K);

        return sha1Of(mBytes.data()).dup;
    }

    // M2 = SHA1(A | M1 | K)
    ubyte[] calculateM2(in ubyte[] A, in ubyte[] M1, in ubyte[] K) const
    {
        auto amk = appender!(ubyte[]);
        amk.put(A);
        amk.put(M1);
        amk.put(K);

        return sha1Of(amk.data()).dup;
    }
}

private ubyte[] interleave(in ubyte[] S)
{
    // skip zeros and skip odd byte
    ubyte[] T = S.dup;
    while(T[0] == 0 || T.length %2 != 0)
        T = T[1..$];

    assert(T.length != 0);

    ubyte[] E = T.stride(2).array();
    ubyte[] G = sha1Of(E).dup;

    ubyte[] F = T[1..$].stride(2).array();
    ubyte[] H = sha1Of(F).dup;

    ubyte[] K = roundRobin(G, H).array();
    return K;
}

/++
+ Handles clientside challenge process
+ All data expected in bigEndian format
+/
class ClientChallenge(SRPTYPE)
{
    this(inout ubyte[] a, SRPTYPE srp) pure
    {
        import std.conv;
    	this.a = a.to!(typeof(this.a));
        this.srp = srp;
    }
    const(ubyte[]) A()
    {
        return srp.calculateA(a);
    }
    // calc using data from server
    immutable(ClientProof) challenge(in ubyte[] username, in ubyte[] password, in ubyte[] salt, in ubyte[] B)
    {
        return srp.clientChallange(username, password, salt, B, a, A);
    }
private:
    immutable ubyte[] a; // private key
    SRPTYPE srp;
}

immutable class ClientProof
{
    this(in ubyte[] K, in ubyte[] M1, in ubyte[] M2) pure 
    {
        this.M1 = M1.to!(typeof(this.M1));
        this.M2 = M2.to!(typeof(this.M2));
        this.K = K.to!(typeof(this.K));
    }
    immutable (ubyte[]) authenticate(in ubyte[] M2) pure
    {
        if (this.M2 != M2)
            return null;
        return K;
    }
    ubyte[] M1;
private:
    ubyte[] K;
    ubyte[] M2;
}

/++
+ Handles serverside challenge process
+/
class ServerChallenge(SRPTYPE)
{
    this(inout ubyte[] b, SRPTYPE srp) pure
    {
        import std.conv;
    	this.b = b.to!(typeof(this.b));
        this.srp = srp;
    }

    ubyte[] calculateB(in ubyte[] userv)
    {
        return srp.calculateB(userv, b).toByteArray(SRPTYPE.IOEndian);
    }
    
	immutable(ServerProof) challenge(in ubyte[] username, in ubyte[] usersalt, in ubyte[] userv, in ubyte[] A)
	{
		return srp.serverChallange(username, usersalt, userv, A, b);
	}

private:
    immutable ubyte[] b;
    SRPTYPE srp;
}

immutable class ServerProof
{
    /++
    + Returns a tuple(M2, K), M2 needs to be sent to client, K is the session key.
    +/
    version(unittest)
    {
        this(in ubyte[] B, in ubyte[] M1, in ubyte[] M2, in ubyte[] K, in ubyte[] S)
        {
            this.B = B.to!(typeof(this.B));
            this.M1 = M1.to!(typeof(this.M1));
            this.M2 = M2.to!(typeof(this.M2));
            this.K = K.to!(typeof(this.K));
            this.S = S.to!(typeof(this.S));
        }
    }
    else
    {
        this(in ubyte[] B, in ubyte[] M1, in ubyte[] M2, in ubyte[] K)
        {
            this.B = B.to!(typeof(this.B));
            this.M1 = M1.to!(typeof(this.M1));
            this.M2 = M2.to!(typeof(this.M2));
            this.K = K.to!(typeof(this.K));
        }
    }

    /// Returns *tuple(M2, K)
    auto authenticate(in ubyte[] M1)
    {
        if (M1 != this.M1)
            return null;
        return new Tuple!(immutable ubyte[], "M2",immutable  ubyte[], "K")(M2, K);
    }
    ubyte[] B; // server public key
    ubyte[] M1;
private:
    ubyte[] M2;
    ubyte[] K; // session key
    version(unittest)
        ubyte[] S;
}

unittest {
    import util.test;
    import std.stdio;
    mixin(test!("srp"));
    // data from the rfc
    auto N = cast(ubyte[])x"EEAF0AB9 ADB38DD6 9C33F80A FA8FC5E8 60726187 75FF3C0B 9EA2314C
        9C256576 D674DF74 96EA81D3 383B4813 D692C6E0 E0D5D8E2 50B98BE4
        8E495C1D 6089DAD1 5DC7D7B4 6154D6B6 CE8EF4AD 69B15D49 82559B29
        7BCF1885 C529F566 660E57EC 68EDBC3C 05726CC0 2FD4CBF4 976EAA9A
        FD5138FE 8376435B 9FC61D2F C0EB06E3";
    uint g = 2;
    auto username = cast(ubyte[])"alice";
    auto password = cast(ubyte[])"password123";
    auto s = cast(ubyte[])x"BEB25379 D1A8581E B5A72767 3A2441EE";
    auto a = cast(ubyte[])x"60975527 035CF2AD 1989806F 0407210B C81EDC04 E2762A56 AFD529DD DA2D4393";
    auto b = cast(ubyte[])x"E487CB59 D31AC550 471E81F0 0F6928E0 1DDA08E9 74A004F4 9E61F5D1 05284D20";
    auto v = cast(ubyte[])x"7E273DE8 696FFC4F 4E337D05 B4B375BE B0DDE156 9E8FA00A 9886D812
        9BADA1F1 822223CA 1A605B53 0E379BA4 729FDC59 F105B478 7E5186F5
        C671085A 1447B52A 48CF1970 B4FB6F84 00BBF4CE BFBB1681 52E08AB5
        EA53D15C 1AFF87B2 B9DA6E04 E058AD51 CC72BFC9 033B564E 26480D78
        E955A5E2 9E7AB245 DB2BE315 E2099AFB";
    auto A = cast(ubyte[])x"61D5E490 F6F1B795 47B0704C 436F523D D0E560F0 C64115BB 72557EC4
            4352E890 3211C046 92272D8B 2D1A5358 A2CF1B6E 0BFCF99F 921530EC
            8E393561 79EAE45E 42BA92AE ACED8251 71E1E8B9 AF6D9C03 E1327F44
            BE087EF0 6530E69F 66615261 EEF54073 CA11CF58 58F0EDFD FE15EFEA
            B349EF5D 76988A36 72FAC47B 0769447B";
    auto B = cast(ubyte[])x"BD0C6151 2C692C0C B6D041FA 01BB152D 4916A1E7 7AF46AE1 05393011
            BAF38964 DC46A067 0DD125B9 5A981652 236F99D9 B681CBF8 7837EC99
            6C6DA044 53728610 D0C6DDB5 8B318885 D7D82C7F 8DEB75CE 7BD4FBAA
            37089E6F 9C6059F3 88838E7A 00030B33 1EB76840 910440B1 B27AAEAE
            EB4012B7 D7665238 A8E3FB00 4B117B58";

    auto u = cast(ubyte[])x"CE38B959 3487DA98 554ED47D 70A7AE5F 462EF019";
    auto secret = cast(ubyte[])x"B0DC82BA BCF30674 AE450C02 87745E79 90A3381F 63B387AA F271A10D
        233861E3 59B48220 F7C4693C 9AE12B0A 6F67809F 0876E2D0 13800D6C
        41BB59B6 D5979B5C 00A172B4 A2A5903A 0BDCAF8A 709585EB 2AFAFA8F
        3499B200 210DCC1F 10EB3394 3CD67FC8 8A2F39A4 BE5BEC4E C0A3212D
        C346D7E4 74B29EDE 8A469FFE CA686E5A";

    auto srp = new SRP!(Endian.bigEndian)(N, [cast(ubyte)2]);

    assert(srp.calculate_v(srp.calculate_x(s, username, password)).toByteArray(Endian.bigEndian) == v);

    assert(srp.calculate_u(A, B).toByteArray(Endian.bigEndian) == u);

    auto client = new ClientChallenge!(typeof(srp))(a, srp);

    assert(A == client.A);

    auto server = new ServerChallenge!(typeof(srp))(b, srp);
    assert(B == server.calculateB(v));
    auto serverProof = server.challenge(username, s, v, A);
    assert(B == serverProof.B);
    assert(secret == serverProof.S);
    
    auto clientProof = client.challenge(username, password, s, B);

    assert(clientProof.K == serverProof.K);
}

ubyte[] binary(string s)
{
    return cast(ubyte[]) s;
}

unittest {
    import util.test;
    import std.stdio;
    mixin(test!("srp - server"));
    
    // test values are from raczman's gow project
    auto N = cast(ubyte[])x"894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7";
    auto username = cast(ubyte[])"ASD@ASD";
    auto password = cast(ubyte[])"ASDASDASD";
    auto xbytes = binary(x"C2A999E9C6552C657B289ED2EBBBF0A9509C3658").reverse;
    auto s = binary(x"CBF0A403F68FF107053EDA81A68C4B296433232E31F3835A076ED58C00604051").reverse;
    auto b = binary(x"6B5B4C4C7024745DF05296CA0648222BA9EF8761").reverse;
    auto v = binary(x"42DE78BFD0357EC0D38F854A0DA98B783B99A15CD9A460521EA18B4B7BF67F27").reverse;
    auto A = binary(x"395FC20352ADCE8F3DBD083FD95F088043AD65B172652042229309CBC4372997").reverse;
    auto B = binary(x"48780A8DD9FA107C0E271ADFA8D8FD57F56620FA144656F1B9132C6CE4F8A1E7").reverse;
    auto K = binary(x"8F30C8A1B329EEC53D0667A6BC28E715105E075B04FDBE8D79148658E7F2659D4C027E080F8B31F5").reverse;
    auto secret = binary(x"83BE386A7B61F323CD426AC4FD82370CD35E7CB52CEBB734051F2BE0A61B30C4").reverse;
    auto u = binary(x"7EA95BF30E4586558E2589EC7A50BDC258580E9E").reverse;
    auto M1 = binary(x"83907B1F5F4C8D83327C5B46AA5A21AF9E383A41").reverse;
    auto M2 = binary(x"CD0E397721CA5881C1649037A89C11FBF0A05DF3").reverse;

    auto srp = new SRP!(Endian.littleEndian)(N, [cast(ubyte)7], [cast(ubyte)3]);

    auto x = srp.calculate_x(s, username, password);

    import util.struct_printer;
    writeln(x.toHexString);

    assert(x.toByteArray(Endian.littleEndian) == xbytes);
    
    assert(srp.calculate_v(x).toByteArray(Endian.littleEndian) == v);

    auto server = new ServerChallenge!(typeof(srp))(b, srp);
    assert(B == server.calculateB(v));

    assert(srp.calculate_u(A, B).toByteArray(Endian.littleEndian) == u);

    auto serverProof = server.challenge(username, s, v, A);
    assert(B == serverProof.B);
    assert(secret == serverProof.S);
    assert(K == serverProof.K);
    auto authInfo = serverProof.authenticate(M1);
    assert(authInfo !is null);
    assert(authInfo.M2 == M2);
}
