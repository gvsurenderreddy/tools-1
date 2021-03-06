#! /bin/env python
import rpm
source = 1
patch = 2
noSource = 9
noPatch = 10

tag_filename = 0
tag_category = 2
# 0: Source
# 1: Patch
# 9: NoSource
#10: NoPatch

class specParse:
    def __init__(self, specFileName):
        self.specFileName = specFileName
        rpm.addMacro('_ipv6', '1')
        ts = rpm.ts()
        self.spec = ts.parseSpec(specFileName)
        self.header = self.spec.header()
        self.sources = self.spec.sources()
        ts.clean()
    def getSrpmName(self):
        suffix = '.src.rpm'
        for src in self.sources:
            if src[tag_category] == noSource:
                suffix = '.nosrc.rpm'
        srpmName = self.header[rpm.RPMTAG_NAME] + '-' + \
            self.header[rpm.RPMTAG_VERSION] + '-' + \
            self.header[rpm.RPMTAG_RELEASE] + \
            suffix
        return srpmName
    def getSources(self):
        sources = []
        for src in self.sources:
            if src[tag_category] == source:
                sources.append(src[tag_filename].split('/')[-1])
        return sources
    def getNoSources(self):
        noSources = []
        for src in self.sources:
            if src[tag_category] == noSource:
                noSources.append(src[tag_filename])
        return noSources
    def getPatches(self):
        patches = []
        for src in self.sources:
            if src[tag_category] == patch:
                patches.append(src[tag_filename].split('/')[-1])
        return patches
    def getNoPatches(self):
        noPatches = []
        for src in self.sources:
            if src[tag_category] == noPatch:
                noPatches.append(src[tag_filename])
        return noPatches

if __name__ == "__main__":
    import sys
#    try:
    if True:
        spec = specParse(sys.argv[1])
        print spec.getSrpmName()
        print spec.getSources()
        print spec.getNoSources()
        print spec.getPatches()
        print spec.getNoPatches()
    else:
#    except:
        print "USAGE: ./specParse.py specfile"

