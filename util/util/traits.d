module util.traits;

/+
 + Tests whenever there's versionString version defined
 +/
mixin template Versions()
{
    template isDefined(string versionString)
    {
        mixin ("version(" ~ versionString ~ ") enum isDefined = true; else enum isDefined = false;");
    }
}

private {
    mixin Versions versionsTest;

    version = util_traits_is_version_test_true;
    static assert (versionsTest.isDefined!"util_traits_is_version_test_true" && !versionsTest.isDefined!"util_traits_is_version_test_false");
}