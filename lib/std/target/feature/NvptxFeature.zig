const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const NvptxFeature = enum {
    Ptx32,
    Ptx40,
    Ptx41,
    Ptx42,
    Ptx43,
    Ptx50,
    Ptx60,
    Ptx61,
    Ptx63,
    Ptx64,
    Sm_20,
    Sm_21,
    Sm_30,
    Sm_32,
    Sm_35,
    Sm_37,
    Sm_50,
    Sm_52,
    Sm_53,
    Sm_60,
    Sm_61,
    Sm_62,
    Sm_70,
    Sm_72,
    Sm_75,

    pub fn getInfo(self: @This()) FeatureInfo {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Ptx32, "ptx32", "Use PTX version 3.2", "ptx32"),
        FeatureInfo(@This()).create(.Ptx40, "ptx40", "Use PTX version 4.0", "ptx40"),
        FeatureInfo(@This()).create(.Ptx41, "ptx41", "Use PTX version 4.1", "ptx41"),
        FeatureInfo(@This()).create(.Ptx42, "ptx42", "Use PTX version 4.2", "ptx42"),
        FeatureInfo(@This()).create(.Ptx43, "ptx43", "Use PTX version 4.3", "ptx43"),
        FeatureInfo(@This()).create(.Ptx50, "ptx50", "Use PTX version 5.0", "ptx50"),
        FeatureInfo(@This()).create(.Ptx60, "ptx60", "Use PTX version 6.0", "ptx60"),
        FeatureInfo(@This()).create(.Ptx61, "ptx61", "Use PTX version 6.1", "ptx61"),
        FeatureInfo(@This()).create(.Ptx63, "ptx63", "Use PTX version 6.3", "ptx63"),
        FeatureInfo(@This()).create(.Ptx64, "ptx64", "Use PTX version 6.4", "ptx64"),
        FeatureInfo(@This()).create(.Sm_20, "sm_20", "Target SM 2.0", "sm_20"),
        FeatureInfo(@This()).create(.Sm_21, "sm_21", "Target SM 2.1", "sm_21"),
        FeatureInfo(@This()).create(.Sm_30, "sm_30", "Target SM 3.0", "sm_30"),
        FeatureInfo(@This()).create(.Sm_32, "sm_32", "Target SM 3.2", "sm_32"),
        FeatureInfo(@This()).create(.Sm_35, "sm_35", "Target SM 3.5", "sm_35"),
        FeatureInfo(@This()).create(.Sm_37, "sm_37", "Target SM 3.7", "sm_37"),
        FeatureInfo(@This()).create(.Sm_50, "sm_50", "Target SM 5.0", "sm_50"),
        FeatureInfo(@This()).create(.Sm_52, "sm_52", "Target SM 5.2", "sm_52"),
        FeatureInfo(@This()).create(.Sm_53, "sm_53", "Target SM 5.3", "sm_53"),
        FeatureInfo(@This()).create(.Sm_60, "sm_60", "Target SM 6.0", "sm_60"),
        FeatureInfo(@This()).create(.Sm_61, "sm_61", "Target SM 6.1", "sm_61"),
        FeatureInfo(@This()).create(.Sm_62, "sm_62", "Target SM 6.2", "sm_62"),
        FeatureInfo(@This()).create(.Sm_70, "sm_70", "Target SM 7.0", "sm_70"),
        FeatureInfo(@This()).create(.Sm_72, "sm_72", "Target SM 7.2", "sm_72"),
        FeatureInfo(@This()).create(.Sm_75, "sm_75", "Target SM 7.5", "sm_75"),
    };
};
