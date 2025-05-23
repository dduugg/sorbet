#include "main/autogen/subclasses.h"
#include "absl/strings/str_split.h"
#include "common/FileOps.h"
#include "common/sort/sort.h"
#include "common/strings/formatting.h"
#include "core/GlobalState.h"
#include "core/Unfreeze.h"

using namespace std;
namespace sorbet::autogen {

// Analogue of sorbet::FileOps::isFileIgnored that doesn't take a basePath, since
// we don't need one here, and using FileOps' version meant passing some weird,
// hard-to-understand arguments to mimic how other callers use it.
bool Subclasses::isFileIgnored(const string &path, const vector<string> &absoluteIgnorePatterns,
                               const vector<string> &relativeIgnorePatterns) {
    for (auto &p : absoluteIgnorePatterns) {
        if (path.substr(0, p.length()) == p &&
            (sorbet::FileOps::isFile(path, p, 0) || sorbet::FileOps::isFolder(path, p, 0))) {
            return true;
        }
    }
    for (auto &p : relativeIgnorePatterns) {
        // See if /pattern is in string, and that it matches a whole folder or file name.
        int pos = 0;
        while (true) {
            pos = path.find(p, pos);
            if (pos == string_view::npos) {
                break;
            } else if (sorbet::FileOps::isFile(path, p, pos) || sorbet::FileOps::isFolder(path, p, pos)) {
                return true;
            }
            pos += p.length();
        }
    }
    return false;
};

void Subclasses::ChildInfo::mergeDefiningRefWith(core::Loc loc) {
    if (!defining_ref.has_value()) {
        defining_ref.emplace(loc);
        return;
    }

    auto f1 = defining_ref->file();
    auto f2 = loc.file();

    // Take the loc earlier by file.
    if (f1.id() < f2.id()) {
        return;
    }

    if (f2.id() < f1.id()) {
        defining_ref.emplace(loc);
        return;
    }

    auto begin1 = defining_ref->beginPos();
    auto begin2 = loc.beginPos();

    if (begin1 < begin2) {
        return;
    }

    if (begin2 > begin1) {
        defining_ref.emplace(loc);
        return;
    }

    // Assume that there is nothing to do here.
}

// Get all subclasses defined in a particular ParsedFile
optional<Subclasses::Map> Subclasses::listAllSubclasses(core::Context ctx, const ParsedFile &pf,
                                                        const vector<string> &absoluteIgnorePatterns,
                                                        const vector<string> &relativeIgnorePatterns) {
    // Prepend "/" because absoluteIgnorePatterns and relativeIgnorePatterns are always "/"-prefixed
    if (isFileIgnored(fmt::format("/{}", pf.path), absoluteIgnorePatterns, relativeIgnorePatterns)) {
        return nullopt;
    }

    Subclasses::Map out;
    for (const Reference &ref : pf.refs) {
        DefinitionRef defn = ref.parent_of;
        if (!defn.exists()) {
            // This is just a random constant reference and doesn't
            // define a Child < Parent relationship.
            continue;
        }

        auto &mapEntry = out[ref.sym.dealias(ctx)];
        auto &info = mapEntry.entries[defn.data(pf).sym.asClassOrModuleRef()];
        info.mergeDefiningRefWith(ctx.locAt(ref.definitionLoc));
        mapEntry.classKind = ref.parentKind;
    }

    return out;
}

void Subclasses::mergeInto(Subclasses::Entries &out, const Subclasses::Entries &entries) {
    for (auto &[sym, info] : entries) {
        auto &symInfo = out[sym];
        if (info.defining_ref.has_value()) {
            symInfo.mergeDefiningRefWith(info.defining_ref.value());
        }
    }
}

// Generate all descendants of a parent class
// Recursively walks `childMap`, which stores the IMMEDIATE children of subclassed class.
optional<Subclasses::SubclassInfo> Subclasses::descendantsOf(const Subclasses::Map &childMap,
                                                             const core::SymbolRef &parentRef) {
    auto fnd = childMap.find(parentRef);
    if (fnd == childMap.end()) {
        return nullopt;
    }
    const Subclasses::Entries &children = fnd->second.entries;

    Subclasses::Entries out;
    mergeInto(out, children);
    for (const auto &[childRef, _info] : children) {
        auto descendants = Subclasses::descendantsOf(childMap, childRef);
        if (descendants) {
            mergeInto(out, descendants->entries);
        }
    }

    return SubclassInfo(fnd->second.classKind, std::move(out));
}

const core::SymbolRef Subclasses::getConstantRef(const core::GlobalState &gs, string rawName) {
    core::ClassOrModuleRef sym = core::Symbols::root();

    for (auto &n : absl::StrSplit(rawName, "::")) {
        const auto &nameRef = gs.lookupNameUTF8(n);
        if (!nameRef.exists())
            return core::Symbols::noSymbol();
        sym = gs.lookupClassSymbol(sym, gs.lookupNameConstant(nameRef));
    }
    return sym;
}

// Manually patch the child map to account for inheritance that happens at runtime `self.included`
// Please do not add to this list.
void Subclasses::patchChildMap(const core::GlobalState &gs, Subclasses::Map &childMap) {
    auto safeMachineRef = getConstantRef(gs, "Opus::SafeMachine");
    auto riskSafeMachineRef = getConstantRef(gs, "Opus::Risk::Model::Mixins::RiskSafeMachine");
    if (!safeMachineRef.exists() || !riskSafeMachineRef.exists())
        return;
    mergeInto(childMap[safeMachineRef].entries, childMap[riskSafeMachineRef].entries);
}

vector<string> Subclasses::serializeSubclassMap(const core::GlobalState &gs, const Subclasses::Map &descendantsMap,
                                                const vector<core::SymbolRef> &parentNames) {
    vector<string> descendantsMapSerialized;
    for (const auto &parentRef : parentNames) {
        auto fnd = descendantsMap.find(parentRef);
        if (fnd == descendantsMap.end()) {
            continue;
        }
        const Subclasses::SubclassInfo &children = fnd->second;

        string parentName = parentRef.show(gs);

        auto type = children.classKind == ClassKind::Class ? "class" : "module";
        descendantsMapSerialized.emplace_back(fmt::format("{} {}", type, parentName));

        auto subclassesStart = descendantsMapSerialized.size();
        for (const auto &[childRef, info] : children.entries) {
            auto loc = info.defining_ref.value_or(childRef.data(gs)->loc());
            string_view path = gs.getPrintablePath(loc.file().data(gs).path());
            string childName = childRef.show(gs);
            auto type = childRef.data(gs)->isClass() ? "class" : "module";
            descendantsMapSerialized.emplace_back(fmt::format(" {} {} {}", type, childName, path));
        }

        fast_sort_range(descendantsMapSerialized.begin() + subclassesStart, descendantsMapSerialized.end());
    }

    return descendantsMapSerialized;
}

// Generate a list of strings representing the descendants of a given list of parent classes
//
// e.g.
// Parent1
//  Child1
// Parent2
//  Child2
//  Child3
//
// This effectively replaces pay-server's `DescendantsMap` in `InheritedClassesStep` with a much
// faster implementation.
vector<string> Subclasses::genDescendantsMap(const core::GlobalState &gs, Subclasses::Map &childMap,
                                             vector<core::SymbolRef> &parentRefs) {
    Subclasses::patchChildMap(gs, childMap);

    // Generate descendants for each passed-in superclass
    fast_sort(parentRefs, [&gs](const auto &left, const auto &right) { return left.show(gs) < right.show(gs); });
    Subclasses::Map descendantsMap;
    for (const auto &parentRef : parentRefs) {
        // Skip parents that the user asked for but which don't
        // exist or are never subclassed.
        auto fnd = childMap.find(parentRef);
        if (fnd == childMap.end()) {
            continue;
        }

        auto descendants = Subclasses::descendantsOf(childMap, parentRef);
        if (!descendants) {
            // Initialize an empty entry associated with parentName.
            descendantsMap[parentRef];
        } else {
            descendantsMap.emplace(parentRef, std::move(*descendants));
        }
    }

    return Subclasses::serializeSubclassMap(gs, descendantsMap, parentRefs);
};

} // namespace sorbet::autogen
