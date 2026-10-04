# kotlinx.serialization: keep generated serializers for our models
-keepattributes *Annotation*, InnerClasses
-keepclassmembers @kotlinx.serialization.Serializable class com.pujoroute.wear.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.pujoroute.wear.**$$serializer { *; }
