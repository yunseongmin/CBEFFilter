#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>

namespace {

int fail(const char* message)
{
    std::fprintf(stderr, "host_action_lifecycle_contract: %s\n", message);
    return 1;
}

std::string readFile(const std::filesystem::path& path)
{
    std::ifstream stream(path);
    return std::string(std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>());
}

std::string between(const std::string& text, const char* begin, const char* end)
{
    const std::size_t first = text.find(begin);
    if (first == std::string::npos) {
        return {};
    }
    const std::size_t last = text.find(end, first);
    if (last == std::string::npos) {
        return {};
    }
    return text.substr(first, last - first);
}

}

int main(int argc, char* argv[])
{
    if (argc != 2) {
        return fail("expected the OFX adapter source path");
    }
    const std::string source = readFile(argv[1]);
    if (source.empty()) {
        return fail("could not read the OFX adapter source");
    }

    if (source.find("setPageParamOrder") != std::string::npos) {
        return fail("describeInContext must not query optional host page-order storage");
    }

    const std::string changed_param = between(source, "void changedParam(", "private:");
    if (changed_param.empty() || changed_param.find("syncParameterState") == std::string::npos) {
        return fail("conditional parameter state must still update after host user edits");
    }

    if (source.find("addSupportedContext(OFX::eContextFilter)") == std::string::npos ||
        source.find("context != OFX::eContextFilter") == std::string::npos) {
        return fail("the plugin must advertise and enforce its Filter-only host contract");
    }

    std::puts("host_action_lifecycle_contract: PASS (host-safe describe/create lifecycle)");
    return 0;
}
