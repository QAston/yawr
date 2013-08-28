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
+/
final class SRP
{
    protected
    {
        BigNumber N; // "prime"
        BigNumber g; // "generator"
        BigNumber k;
    }

    public ubyte[] Nbytes()
    {
        return N.toByteArray(Endian.bigEndian);
    }

    public ubyte[] gbytes()
    {
        return g.toByteArray(Endian.bigEndian);
    }

    /++
    + Needs to be initialized with prime N and generator g
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
    + Calculates data for clientside authentication
    + Returns ClientProof object
    +/
    immutable(ClientProof) clientChallange(in ubyte[] username, in ubyte[] password, in ubyte[] salt, in ubyte[] Bbytes, in ubyte[] abytes, in ubyte[] Abytes) const
    {
        auto u = calculate_u(Abytes, Bbytes);
        auto x = calculate_x(salt, username, password);
        auto v = calculate_v(x);
        auto A = BigNumber(Abytes, Endian.bigEndian);
        auto B = BigNumber(Bbytes, Endian.bigEndian);
        auto a = BigNumber(abytes, Endian.bigEndian);

        // Secret = (B - (k * v)) ^ (a + (u * x)) % N
        BigNumber S = (B - (k * v)).modExp((a + (u * x)), N);

        auto K = interleave(S.toByteArray(Endian.bigEndian));

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
        auto v = BigNumber(vbytes, Endian.bigEndian);

        auto b = BigNumber(bbytes, Endian.bigEndian);

        BigNumber B = calculateB(v, b);

        auto Bbytes = B.toByteArray(Endian.bigEndian);

        auto A = BigNumber(Abytes, Endian.bigEndian);
        auto u = calculate_u(Abytes, Bbytes);

        // S = (A * v^u) ^ b % N
        BigNumber S = (A * v.modExp(u, N)).modExp(b, N);

        auto K = interleave(S.toByteArray(Endian.bigEndian));

        auto M1 = calculateM1(username, salt, Abytes, Bbytes, K);

        auto M2 = calculateM2(Abytes, M1, K);

        version(unittest)
            return new immutable(ServerProof)(Bbytes, M1, M2, K, S.toByteArray(Endian.bigEndian));
        else
            return new immutable(ServerProof)(Bbytes, M1, M2, K);
    }

    /// A = g^a mod N - client's public key
    ubyte[] calculateA(in ubyte[] abytes) const
    {
        BigNumber a = BigNumber(abytes, Endian.bigEndian);
        return g.modExp(a, N).toByteArray(Endian.bigEndian);
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
        auto v = BigNumber(vbytes, Endian.bigEndian);

        auto b = BigNumber(bbytes, Endian.bigEndian);

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

        return BigNumber(sha1Of(uBytes.data()), Endian.bigEndian);
    }

    // x = SHA1(salt | SHA1(username | ":" | password)
    BigNumber calculate_x(in ubyte[] salt, in ubyte[] username, in ubyte[] password) const
    {
        auto ucp = appender!(ubyte[]);
        ucp.put(username);
        ucp.put(':');
        ucp.put(password);

        return BigNumber(sha1Of(salt ~ sha1Of(ucp.data())), Endian.bigEndian);
    }

    // M = SHA1(SHA1(N) XOR SHA1(g) | SHA1(username) | s | A | B | K)
    ubyte[] calculateM1(in ubyte[] username, in ubyte[] s, in ubyte[] A, in ubyte[] B, in ubyte[] K) const
    {
        auto mBytes = appender!(ubyte[])();

        foreach(a ; zip(sha1Of(N.toByteArray(Endian.bigEndian))[], sha1Of(g.toByteArray(Endian.bigEndian))[]))
        {
            mBytes.put((a[0] ^ a[1]).to!ubyte);
        }
        mBytes.put(sha1Of(username).dup);
        mBytes.put(s);
        mBytes.put(A);
        mBytes.put(B);
        mBytes.put(K);

        return sha1Of(mBytes.data());
    }

    // M2 = SHA1(A | M1 | K)
    ubyte[] calculateM2(in ubyte[] A, in ubyte[] M1, in ubyte[] K) const
    {
        auto amk = appender!(ubyte[]);
        amk.put(A);
        amk.put(M1);
        amk.put(K);

        return sha1Of(amk.data());
    }

    static ubyte[] interleave(in ubyte[] S)
    {
        // skip zeros and skip odd byte
        ubyte[] T = S.dup;
        while(T[0] == 0 || T.length %2 != 0)
            T = T[1..$];

        assert(T.length != 0);

        ubyte[] E = T.stride(2).array();
        ubyte[] G = sha1Of(E);

        ubyte[] F = T[1..$].stride(2).array();
        ubyte[] H = sha1Of(F);

        ubyte[] K = roundRobin(G, H).array();
        return K;
    }
}

/++
+ Handles clientside challenge process
+ All data expected in bigEndian format
+/
class ClientChallenge
{
    this(inout ubyte[] a, SRP srp) pure
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
    SRP srp;
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
+ All data expected in bigEndian format
+/
class ServerChallenge
{
    this(inout ubyte[] b, SRP srp) pure
    {
        import std.conv;
    	this.b = b.to!(typeof(this.b));
        this.srp = srp;
    }

    ubyte[] calculateB(in ubyte[] userv)
    {
        return srp.calculateB(userv, b).toByteArray(Endian.bigEndian);
    }
    
	immutable(ServerProof) challenge(in ubyte[] username, in ubyte[] usersalt, in ubyte[] userv, in ubyte[] A)
	{
		return srp.serverChallange(username, usersalt, userv, A, b);
	}

private:
    immutable ubyte[] b;
    SRP srp;
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

    auto authenticate(in ubyte[] M1)
    {
        import std.stdio;
        writeln(M1);
        writeln(this.M1);
        writeln(M2);
        if (M1 != this.M1)
            return null;
        return new Tuple!(immutable ubyte[],immutable  ubyte[])(M2, K);
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

    auto srp = new SRP(N, [cast(ubyte)2]);

    assert(srp.calculate_v(srp.calculate_x(s, username, password)).toByteArray(Endian.bigEndian) == v);

    assert(srp.calculate_u(A, B).toByteArray(Endian.bigEndian) == u);

    auto client = new ClientChallenge(a, srp);

    assert(A == client.A);

    auto server = new ServerChallenge(b, srp);
    assert(B == server.calculateB(v));
    auto serverProof = server.challenge(username, s, v, A);
    assert(B == serverProof.B);
    assert(secret == serverProof.S);
    
    auto clientProof = client.challenge(username, password, s, B);

    assert(clientProof.K == serverProof.K);
}