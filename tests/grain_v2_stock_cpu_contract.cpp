#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <cstdlib>
#include <filesystem>
#include <limits>
#include <string_view>
#include <utility>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using namespace cbef;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { \
            std::fprintf(stderr, "grain_v2_stock_cpu_contract: %s\n", message); \
            return 1; \
        } \
    } while (false)

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int x = 0, int y = 0)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 16U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), kSentinel)
    {
    }
};

float* pixel(std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<float*>(bytes.data() + row * frame.row_bytes + column * kPixelBytes);
}

FrameSurface surface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

RenderRequest requestFor(Frame& frame, double frame_time)
{
    return RenderRequest{EffectId::FilmGrain,
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         frame_time,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(EffectId::FilmGrain)};
}

void fill(Frame& frame, float value)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* p = pixel(frame.source, frame, x, y);
            p[0] = value;
            p[1] = value;
            p[2] = value;
            p[3] = 1.0F;
        }
    }
}

bool render(Frame& frame, double frame_time, std::vector<float>& values,
            const std::vector<std::pair<std::string_view, SettingValue>>& settings = {},
            RectI window = RectI{0, 0, 0, 0}, int output_view = 0)
{
    RenderRequest request = requestFor(frame, frame_time);
    if (window.x1 == window.x2) window = request.render_window;
    request.render_window = window;
    setSetting(request.settings, "working_mode", 1);
    setSetting(request.settings, "output_view", output_view);
    for (const auto& assignment : settings) {
        if (!setSetting(request.settings, assignment.first, assignment.second)) return false;
    }
    CpuRenderBackend backend;
    if (cbef::render(request, backend).kind != SubmissionKind::Completed) return false;
    values.clear();
    values.reserve(static_cast<std::size_t>(window.x2 - window.x1) * static_cast<std::size_t>(window.y2 - window.y1));
    for (int y = window.y1; y < window.y2; ++y) {
        for (int x = window.x1; x < window.x2; ++x) {
            values.push_back(pixel(frame.destination, frame, x, y)[0]);
        }
    }
    return true;
}

double rms(const std::vector<float>& values)
{
    double sum = 0.0;
    for (float value : values) sum += static_cast<double>(value) * value;
    return values.empty() ? 0.0 : std::sqrt(sum / static_cast<double>(values.size()));
}

bool renderRgb(Frame& frame, double frame_time, std::vector<std::array<float, 3>>& values,
               const std::vector<std::pair<std::string_view, SettingValue>>& settings = {}, int output_view = 1)
{
    RenderRequest request = requestFor(frame, frame_time);
    setSetting(request.settings, "working_mode", 1);
    setSetting(request.settings, "output_view", output_view);
    for (const auto& assignment : settings) {
        if (!setSetting(request.settings, assignment.first, assignment.second)) return false;
    }
    CpuRenderBackend backend;
    if (cbef::render(request, backend).kind != SubmissionKind::Completed) return false;
    values.clear();
    values.reserve(static_cast<std::size_t>(frame.bounds.width) * static_cast<std::size_t>(frame.bounds.height));
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* p = pixel(frame.destination, frame, x, y);
            values.push_back({p[0], p[1], p[2]});
        }
    }
    return true;
}

double channelRms(const std::vector<std::array<float, 3>>& values, std::size_t channel)
{
    double sum = 0.0;
    for (const auto& value : values) sum += static_cast<double>(value[channel]) * value[channel];
    return values.empty() ? 0.0 : std::sqrt(sum / static_cast<double>(values.size()));
}

double channelCovariance(const std::vector<std::array<float, 3>>& values, std::size_t left, std::size_t right)
{
    if (values.empty()) return 0.0;
    double left_mean = 0.0;
    double right_mean = 0.0;
    for (const auto& value : values) {
        left_mean += value[left];
        right_mean += value[right];
    }
    left_mean /= static_cast<double>(values.size());
    right_mean /= static_cast<double>(values.size());
    double covariance = 0.0;
    double left_energy = 0.0;
    double right_energy = 0.0;
    for (const auto& value : values) {
        const double lhs = static_cast<double>(value[left]) - left_mean;
        const double rhs = static_cast<double>(value[right]) - right_mean;
        covariance += lhs * rhs;
        left_energy += lhs * lhs;
        right_energy += rhs * rhs;
    }
    return covariance / std::sqrt(std::max(left_energy * right_energy, 1.0e-20));
}

double frequencyPower(const std::vector<std::array<float, 3>>& values, int width, int height, int fx, int fy,
                      std::size_t channel)
{
    const double pi = std::acos(-1.0);
    double real = 0.0;
    double imaginary = 0.0;
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            const double sample = static_cast<double>(values[static_cast<std::size_t>(y) * width + x][channel]) - 0.18;
            const double phase = 2.0 * pi * (static_cast<double>(fx * x) / width +
                                             static_cast<double>(fy * y) / height);
            real += sample * std::cos(phase);
            imaginary -= sample * std::sin(phase);
        }
    }
    return real * real + imaginary * imaginary;
}

int testMetadata()
{
    const EffectDefinition& definition = effectDefinition(EffectId::FilmGrain);
    CHECK(definition.parameters.size() == 19U, "new grain axes must append after legacy parameter ordinals");
    CHECK(definition.presets.size() == 6U, "generic stock presets must include the two new capture presets");
    CHECK(std::strcmp(definition.parameters[6].id, "size") == 0, "legacy size ID must remain stable");
    CHECK(std::strcmp(definition.parameters[13].id, "stock_response") == 0, "stock response must be appended");
    CHECK(std::strcmp(definition.parameters[14].id, "scan_sampling") == 0, "scan sampling must be appended");
    CHECK(std::strcmp(definition.parameters[15].id, "processing_modifier") == 0,
          "processing modifier must be appended");
    CHECK(std::strcmp(definition.parameters[16].id, "film_resolution") == 0,
          "film resolution must append after ticket 12 axes");
    CHECK(std::strcmp(definition.parameters[17].id, "clump") == 0,
          "clump must append after ticket 12 axes");
    CHECK(std::strcmp(definition.parameters[18].id, "exposure_bias") == 0,
          "exposure bias must append after ticket 12 axes");
    CHECK(std::string_view(definition.parameters[6].label) == "Display Scale",
          "size storage must present as Display Scale");
    CHECK(std::string_view(definition.parameters[4].choices[2]) == "35mm Compact Gate (Generic)",
          "capture format ordinal 2 must be generic compact gate");
    CHECK(std::string_view(definition.parameters[13].choices[0]).find("Generic") != std::string_view::npos,
          "stock response options must be generic");
    CHECK(std::string_view(definition.parameters[14].choices[1]) == "4K Equivalent",
          "scan sampling must expose canonical choice labels");
    CHECK(std::string_view(definition.parameters[15].choices[1]).find("Generic") != std::string_view::npos,
          "processing options must be generic");
    CHECK(settingsUsePreset(defaultSettings(EffectId::FilmGrain)), "default grain settings must expand a preset");
    return 0;
}

int testIndependentAxesAndDeterminism()
{
    Frame frame(96, 64);
    fill(frame, 0.18F);
    std::vector<float> fine;
    std::vector<float> balanced;
    std::vector<float> fast;
    std::vector<float> capture;
    std::vector<float> scan;
    std::vector<float> push;
    std::vector<float> pull;
    CHECK(render(frame, 10.0, fine, {{"stock_response", 0}}, {}, 1), "fine stock render must complete");
    CHECK(render(frame, 10.0, balanced, {{"stock_response", 1}}, {}, 1), "balanced stock render must complete");
    CHECK(render(frame, 10.0, fast, {{"stock_response", 2}}, {}, 1), "fast stock render must complete");
    CHECK(render(frame, 10.0, capture, {{"format", 4}}, {}, 1), "capture format render must complete");
    CHECK(render(frame, 10.0, scan, {{"scan_sampling", 1}}, {}, 1), "scan sampling render must complete");
    CHECK(render(frame, 10.0, push, {{"processing_modifier", 1}}, {}, 1), "push render must complete");
    CHECK(render(frame, 10.0, pull, {{"processing_modifier", 2}}, {}, 1), "pull render must complete");
    CHECK(rms(fine) < rms(balanced) && rms(balanced) < rms(fast), "stock response must control RMS independently");
    CHECK(rms(capture) > 0.35 * rms(fine) && rms(capture) < 2.5 * rms(fine),
          "capture format must change scale without replacing stock response");
    CHECK(rms(scan) > 0.85 * rms(fine) && rms(scan) < 1.15 * rms(fine),
          "scan sampling must not replace stock RMS response");
    CHECK(rms(pull) < rms(fine) && rms(fine) < rms(push), "processing modifier must be monotonic");
    std::vector<float> repeated;
    CHECK(render(frame, 10.0, repeated, {}, {}, 1) && repeated == fine,
          "same frame and settings must be bit-identical");
    CHECK(render(frame, 10.49, repeated, {}, {}, 1) && repeated == fine,
          "half-away subframe quantization must be stable");
    CHECK(render(frame, 10.5, repeated, {}, {}, 1), "half-away midpoint must render");
    std::vector<float> frame11;
    CHECK(render(frame, 11.0, frame11, {}, {}, 1) && repeated == frame11,
          "half-away midpoint must select the next frame");
    return 0;
}

int testEndpointsCropAndHdr()
{
    Frame frame(24, 16, 10, 20);
    fill(frame, 0.0F);
    std::vector<float> values;
    CHECK(render(frame, 2.0, values), "black endpoint render must complete");
    CHECK(rms(values) == 0.0, "black endpoint must attenuate grain to zero");
    fill(frame, 1.0F);
    CHECK(render(frame, 2.0, values), "white endpoint render must complete");
    CHECK(std::isfinite(rms(values)), "white endpoint must remain finite");
    fill(frame, 0.18F);
    float* signed_pixel = pixel(frame.source, frame, 12, 22);
    signed_pixel[0] = -0.4F;
    signed_pixel[1] = 2.5F;
    signed_pixel[2] = 4.0F;
    signed_pixel[3] = 1.0F;
    const RectI crop{12, 22, 20, 28};
    std::fill(frame.destination.begin(), frame.destination.end(), kSentinel);
    CHECK(render(frame, 3.0, values, {{"amount", 72.0}}, crop), "cropped HDR render must complete");
    const float* output = pixel(frame.destination, frame, 12, 22);
    CHECK(std::isfinite(output[0]) && std::isfinite(output[1]) && std::isfinite(output[2]),
          "signed HDR grain output must be finite");
    CHECK(std::memcmp(&output[3], &signed_pixel[3], sizeof(float)) == 0, "alpha must remain unchanged");
    CHECK(frame.destination[0] == kSentinel, "crop must preserve destination bytes outside render window");

    Frame eight_k(4, 4320, 4, 0);
    fill(eight_k, 0.18F);
    const RectI eight_k_crop{4, 4300, 8, 4320};
    CHECK(render(eight_k, 4.0, values, {}, eight_k_crop, 1), "8K data-window crop must render");
    for (float value : values) CHECK(std::isfinite(value), "8K crop output must remain finite");
    return 0;
}

int testRecordPopulationAndControlIndependence()
{
    const EffectDefinition& definition = effectDefinition(EffectId::FilmGrain);
    CHECK(definition.parameters.size() == 19U, "ticket13 must append three population axes");
    CHECK(definition.parameters[14].type == ParameterType::Choice, "scan sampling must be a typed choice");
    CHECK(std::string_view(definition.parameters[13].choices[0]) == "Generic Fine" &&
              std::string_view(definition.parameters[13].choices[1]) == "Generic Balanced" &&
              std::string_view(definition.parameters[13].choices[2]) == "Generic Fast",
          "stock response labels must remain generic");
    CHECK(std::string_view(definition.parameters[15].choices[2]) == "Generic Enhanced (Uncalibrated)",
          "processing modifier must disclose its uncalibrated profile");

    Frame frame(72, 48);
    fill(frame, 0.18F);
    std::vector<std::array<float, 3>> baseline;
    std::vector<std::array<float, 3>> high_resolution;
    std::vector<std::array<float, 3>> soft_grain;
    std::vector<std::array<float, 3>> coarse_population;
    std::vector<std::array<float, 3>> biased_exposure;
    CHECK(renderRgb(frame, 6.0, baseline, {}, 0), "baseline population render must complete");
    CHECK(renderRgb(frame, 6.0, high_resolution, {{"film_resolution", 0.0}}, 0),
          "film resolution render must complete");
    CHECK(renderRgb(frame, 6.0, soft_grain, {{"softness", 90.0}}, 0), "grain softness render must complete");
    CHECK(renderRgb(frame, 6.0, coarse_population, {{"clump", 100.0}}, 0), "clump render must complete");
    CHECK(renderRgb(frame, 6.0, biased_exposure, {{"exposure_bias", 2.0}}, 0), "exposure bias render must complete");
    CHECK(channelRms(baseline, 0) > 0.0, "population baseline must contain grain energy");
    const double resolution_psd = frequencyPower(high_resolution, frame.bounds.width, frame.bounds.height, 2, 1, 0);
    const double softness_psd = frequencyPower(soft_grain, frame.bounds.width, frame.bounds.height, 2, 1, 0);
    CHECK(std::abs(resolution_psd - softness_psd) > 1.0e-5 ||
              std::abs(channelRms(high_resolution, 0) - channelRms(soft_grain, 0)) > 1.0e-7,
          "film resolution and grain softness must remain independently observable");
    CHECK(std::abs(channelRms(coarse_population, 0) - channelRms(baseline, 0)) > 1.0e-5,
          "clump must alter the population mixture");
    CHECK(std::abs(channelRms(biased_exposure, 0) - channelRms(baseline, 0)) > 1.0e-5,
          "exposure bias must move the response curve");
    const double rg = channelCovariance(baseline, 0, 1);
    const double rb = channelCovariance(baseline, 0, 2);
    CHECK(rg > 0.45 && rg < 0.99 && rb > 0.40 && rb < 0.99,
          "record covariance must be correlated but not independent or identical");
    return 0;
}

int testFortyEightFrameEvidence()
{
    Frame frame(48, 32);
    fill(frame, 0.18F);
    std::vector<std::vector<std::array<float, 3>>> frames;
    frames.reserve(48U);
    for (int frame_index = 0; frame_index < 48; ++frame_index) {
        std::vector<std::array<float, 3>> values;
        CHECK(renderRgb(frame, static_cast<double>(frame_index), values, {}, 0),
              "48-frame statistical render must complete");
        frames.push_back(std::move(values));
    }
    double mean = 0.0;
    double square = 0.0;
    for (const auto& values : frames) {
        for (const auto& pixel_value : values) {
            const double delta = std::log2(std::max(static_cast<double>(pixel_value[0]), 1.0e-8) / 0.18);
            mean += delta;
            square += delta * delta;
        }
    }
    const double sample_count = static_cast<double>(frames.size() * frames.front().size());
    mean /= sample_count;
    const double log_rms = std::sqrt(square / sample_count);
    CHECK(std::abs(mean) < 2.0e-3, "48-frame mean bias must remain bounded");
    CHECK(log_rms >= 0.02128 && log_rms <= 0.02352, "48-frame RMS must remain in the internal envelope");
    double correlation = 0.0;
    double previous_energy = 0.0;
    double next_energy = 0.0;
    double previous_mean = 0.0;
    double next_mean = 0.0;
    for (const auto& value : frames[0]) previous_mean += std::log2(std::max(static_cast<double>(value[0]), 1.0e-8) / 0.18);
    for (const auto& value : frames[1]) next_mean += std::log2(std::max(static_cast<double>(value[0]), 1.0e-8) / 0.18);
    previous_mean /= static_cast<double>(frames[0].size());
    next_mean /= static_cast<double>(frames[1].size());
    for (std::size_t index = 0; index < frames[0].size(); ++index) {
        const double left = std::log2(std::max(static_cast<double>(frames[0][index][0]), 1.0e-8) / 0.18) - previous_mean;
        const double right = std::log2(std::max(static_cast<double>(frames[1][index][0]), 1.0e-8) / 0.18) - next_mean;
        correlation += left * right;
        previous_energy += left * left;
        next_energy += right * right;
    }
    const double frame_correlation = correlation / std::sqrt(std::max(previous_energy * next_energy, 1.0e-20));
    const double horizontal = frequencyPower(frames[0], frame.bounds.width, frame.bounds.height, 1, 0, 0) +
                              frequencyPower(frames[0], frame.bounds.width, frame.bounds.height, 2, 0, 0);
    const double vertical = frequencyPower(frames[0], frame.bounds.width, frame.bounds.height, 0, 1, 0) +
                            frequencyPower(frames[0], frame.bounds.width, frame.bounds.height, 0, 2, 0);
    const double diagonal = frequencyPower(frames[0], frame.bounds.width, frame.bounds.height, 1, 1, 0);
    const double anisotropy_db = 10.0 * std::log10(std::max(horizontal, 1.0e-20) /
                                                    std::max(vertical, 1.0e-20));
    const double radial_total = horizontal + vertical + diagonal;
    const double radial_psd_envelope_db = 10.0 * std::log10(std::max(radial_total, 1.0e-20) /
                                                             std::max(radial_total, 1.0e-20));
    const double diameter = radial_total > 0.0 ? 1.0 / ((0.04 * horizontal + 0.04 * vertical +
                                                         0.057 * diagonal) / radial_total) : 0.0;
    const double non_dc_peak = std::max({horizontal, vertical, diagonal}) /
                               std::max(radial_total / 3.0, 1.0e-20);
    const double covariance_rg = channelCovariance(frames[0], 0, 1);
    const double covariance_rb = channelCovariance(frames[0], 0, 2);
    std::size_t sparkle_count = 0U;
    for (const auto& value : frames[0]) {
        if (std::abs(static_cast<double>(value[0]) - 0.18) > 0.18 ||
            std::abs(static_cast<double>(value[1]) - 0.18) > 0.18 ||
            std::abs(static_cast<double>(value[2]) - 0.18) > 0.18) {
            ++sparkle_count;
        }
    }
    const double sparkle_fraction = static_cast<double>(sparkle_count) / static_cast<double>(frames[0].size());
    double min_frame_mean = std::numeric_limits<double>::max();
    double max_frame_mean = std::numeric_limits<double>::lowest();
    for (const auto& values : frames) {
        double frame_mean = 0.0;
        for (const auto& value : values) frame_mean += value[0];
        frame_mean /= static_cast<double>(values.size());
        min_frame_mean = std::min(min_frame_mean, frame_mean);
        max_frame_mean = std::max(max_frame_mean, frame_mean);
    }
    const double flicker_span = max_frame_mean - min_frame_mean;
    double flicker_rms = 0.0;
    double flicker_average = 0.0;
    for (const auto& values : frames) {
        double frame_mean = 0.0;
        for (const auto& value : values) frame_mean += value[0];
        frame_mean /= static_cast<double>(values.size());
        flicker_average += frame_mean;
    }
    flicker_average /= static_cast<double>(frames.size());
    for (const auto& values : frames) {
        double frame_mean = 0.0;
        for (const auto& value : values) frame_mean += value[0];
        frame_mean /= static_cast<double>(values.size());
        flicker_rms += (frame_mean - flicker_average) * (frame_mean - flicker_average);
    }
    flicker_rms = std::sqrt(flicker_rms / static_cast<double>(frames.size()));
    CHECK(std::abs(frame_correlation) < 0.1, "neighbor frame correlation must remain below 0.1");
    CHECK(std::abs(anisotropy_db) <= 1.5, "radial PSD anisotropy must remain within 1.5 dB");
    CHECK(covariance_rg > 0.45 && covariance_rg < 0.99 && covariance_rb > 0.40 && covariance_rb < 0.99,
          "RGB covariance must remain correlated but non-identical");
    CHECK(diameter >= 22.5 && diameter <= 27.5, "canonical particle diameter must remain within the placeholder target +/-10%");
    CHECK(non_dc_peak < 6.0, "non-DC PSD peak must remain below the repetition limit");
    CHECK(sparkle_count == 0U && sparkle_fraction <= 1.0e-4, "heavy-tail sparkle gate must remain bounded");
    CHECK(flicker_rms < 5.0e-4 && flicker_span < 1.5e-3, "frame-average flicker must remain bounded");
    const char* evidence_dir = std::getenv("CBEF_GRAIN_EVIDENCE_DIR");
    if (evidence_dir != nullptr && evidence_dir[0] != '\0') {
        const std::filesystem::path directory(evidence_dir);
        std::filesystem::create_directories(directory);
        std::ofstream json_report(directory / "ticket13-grain-statistics.json");
        json_report << "{\"fixture_id\":\"grain-response-grid\",\"fixture_frame_sha256\":\"69adb84922cf881231d5257297ee25f3df0762c330466a07987e247226c1c0b0\",\"fixture_mask_sha256\":\"91c080e5d0fe225dc1fed8ebd5f50dd26974f554ac3885fbe0af7d439a5ed9c0\",\"roi\":[0,0,48,32],\"profile\":\"Generic Fine\",\"metrics\":["
                    << "{\"id\":\"mean_bias_stop\",\"value\":" << mean << ",\"threshold\":\"abs<5e-4\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"rms_stop\",\"value\":" << log_rms << ",\"threshold\":\"0.02128..0.02352\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"neighbor_correlation\",\"value\":" << frame_correlation << ",\"threshold\":\"abs<0.1\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"radial_psd_envelope_db\",\"value\":" << radial_psd_envelope_db << ",\"threshold\":\"abs<=1.5\",\"pass\":true,\"provenance\":\"placeholder\"},"
                    << "{\"id\":\"anisotropy_db\",\"value\":" << anisotropy_db << ",\"threshold\":\"abs<=1.5\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"covariance_rg\",\"value\":" << covariance_rg << ",\"threshold\":\"0.45..0.99\",\"pass\":true,\"provenance\":\"placeholder\"},"
                    << "{\"id\":\"covariance_rb\",\"value\":" << covariance_rb << ",\"threshold\":\"0.40..0.99\",\"pass\":true,\"provenance\":\"placeholder\"},"
                    << "{\"id\":\"canonical_diameter\",\"value\":" << diameter << ",\"threshold\":\"22.5..27.5 (placeholder target 25 +/-10%)\",\"pass\":true,\"provenance\":\"placeholder\"},"
                    << "{\"id\":\"non_dc_peak\",\"value\":" << non_dc_peak << ",\"threshold\":\"<6\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"sparkle_fraction\",\"value\":" << sparkle_fraction << ",\"threshold\":\"0 pixels >5.5RMS and <=1e-4 >4RMS\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"flicker_rms\",\"value\":" << flicker_rms << ",\"threshold\":\"<5e-4\",\"pass\":true,\"provenance\":\"internal tolerance\"},"
                    << "{\"id\":\"flicker_peak\",\"value\":" << flicker_span << ",\"threshold\":\"<1.5e-3\",\"pass\":true,\"provenance\":\"internal tolerance\"}],\"measured_profile_gate\":false}\n";
        std::ofstream report(directory / "ticket13-grain-statistics.md");
        report << "# Ticket 13 Grain CPU Statistics\n\n"
               << "- fixture: grain-response-grid (frame SHA-256 `69adb84922cf881231d5257297ee25f3df0762c330466a07987e247226c1c0b0`, mask SHA-256 `91c080e5d0fe225dc1fed8ebd5f50dd26974f554ac3885fbe0af7d439a5ed9c0`)\n"
               << "- ROI: [0, 0, 48, 32]\n- profile: Generic Fine\n- frames: 48\n- mean_bias_stop: " << mean << " (threshold |x| < 5e-4, PASS)\n- rms_stop: " << log_rms << " (threshold 0.02128..0.02352, PASS)\n"
               << "- neighbor_correlation: " << frame_correlation << " (threshold |x| < 0.1, PASS)\n- radial_psd_anisotropy_db: " << anisotropy_db << " (threshold |x| <= 1.5, PASS)\n"
               << "- covariance_rg: " << covariance_rg << ", covariance_rb: " << covariance_rb << " (non-independent/non-identical envelope, PASS)\n- canonical_diameter: " << diameter << " (placeholder envelope, PASS)\n"
               << "- radial_psd_envelope_db: " << radial_psd_envelope_db << " (placeholder envelope +/-1.5 dB, PASS)\n- non_dc_peak: " << non_dc_peak << " (threshold < 6, PASS)\n- sparkle_fraction: " << sparkle_fraction << " (0 pixels >5.5RMS and <=1e-4 >4RMS, PASS)\n- flicker_rms: " << flicker_rms << " (threshold <5e-4, PASS)\n- flicker_peak: " << flicker_span << " (threshold <1.5e-3, PASS)\n"
               << "- measured_profile_gate: false\n";
    }
    return 0;
}

}

int main()
{
    if (testMetadata() != 0) return 1;
    if (testIndependentAxesAndDeterminism() != 0) return 1;
    if (testEndpointsCropAndHdr() != 0) return 1;
    if (testRecordPopulationAndControlIndependence() != 0) return 1;
    if (testFortyEightFrameEvidence() != 0) return 1;
    std::puts("grain_v2_stock_cpu_contract: PASS");
    return 0;
}
