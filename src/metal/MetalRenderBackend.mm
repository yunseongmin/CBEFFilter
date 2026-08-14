#import <Metal/Metal.h>
#import <Foundation/Foundation.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <dlfcn.h>
#include <limits>
#include <map>
#include <mutex>
#include <new>
#include <string>
#include <vector>

#include "cbef/RenderCore.h"
#include "FrameArena.h"
#include "OpticalSampling.h"
#include "RenderPlan.h"

namespace cbef {
namespace {

struct CopyArguments {
    std::int32_t data_x;
    std::int32_t data_y;
    std::int32_t window_x;
    std::int32_t window_y;
    std::int32_t width;
    std::int32_t height;
    std::uint32_t source_row_bytes;
    std::uint32_t destination_row_bytes;
};

static_assert(sizeof(CopyArguments) == 32U, "Metal v2 copy argument layout must stay stable");

struct HalationArguments {
    std::int32_t data_x;
    std::int32_t data_y;
    std::int32_t window_x;
    std::int32_t window_y;
    std::int32_t width;
    std::int32_t height;
    std::uint32_t source_row_bytes;
    std::uint32_t destination_row_bytes;
    std::uint32_t working_mode;
    std::uint32_t diagnostic_view;
    float mix;
    float amount;
    float radius;
    float threshold;
    float warmth;
    float saturation;
    std::uint32_t highlights_only;
    std::uint32_t alpha_association;
    std::uint32_t render_width;
    std::uint32_t render_height;
    std::uint32_t horizontal_radius;
    std::uint32_t vertical_radius;
    float scale_weight;
    float source_smoothness;
    float global_diffusion;
    float red_bias;
    float blue_compensation;
    float core_protection;
    float background_adaptation;
    std::uint32_t channel;
    float color_target_r;
    float color_target_g;
    float color_target_b;
    float color_emphasis_mix;
    std::uint32_t color_mode;
};

static_assert(sizeof(HalationArguments) == 140U, "Metal Halation argument layout must stay stable");

struct HalationFusedArguments {
    HalationArguments base;
    std::uint32_t pair_offsets[3];
    std::uint32_t pair_counts[3];
    std::uint32_t vertical_pair_offsets[3];
    std::uint32_t vertical_pair_counts[3];
    float scale_weights[3];
};

struct HalationPyramidRG32Arguments {
    HalationArguments base;
    std::uint32_t level_width;
    std::uint32_t level_height;
    std::uint32_t downsample;
    std::uint32_t channel;
    std::uint32_t source_row_stride;
    std::uint32_t output_row_stride;
    std::uint32_t source_plane_stride;
    std::uint32_t output_plane_stride;
    std::uint32_t horizontal_pair_offsets[3];
    std::uint32_t vertical_pair_offsets[3];
    std::uint32_t horizontal_radii[3];
    std::uint32_t vertical_radii[3];
};

static_assert(sizeof(HalationPyramidRG32Arguments) == 220U,
              "Metal Halation RG32 pyramid argument layout must stay stable");

struct HalationPyramidCompositeArguments {
    HalationArguments base;
    std::uint32_t downsample[3];
    std::uint32_t global_branch;
    std::uint32_t initialize;
};

static_assert(sizeof(HalationPyramidCompositeArguments) == 160U,
              "Metal Halation composite argument layout must stay stable");


struct GrainArguments {
    std::int32_t data_x;
    std::int32_t data_y;
    std::int32_t window_x;
    std::int32_t window_y;
    std::int32_t width;
    std::int32_t height;
    std::int32_t source_height;
    std::uint32_t source_row_bytes;
    std::uint32_t destination_row_bytes;
    std::uint32_t working_mode;
    std::uint32_t diagnostic_view;
    float mix;
    std::int32_t format;
    float amount;
    float size;
    float softness;
    float chroma;
    float shadow;
    float midtone;
    float highlight;
    std::uint32_t seed;
    std::int64_t frame;
    std::uint32_t alpha_association;
    std::uint32_t is_identity;
    int stock_response;
    float scan_sampling;
    int processing_modifier;
    float film_resolution;
    float clump;
    float exposure_bias;
    float grain_scale;
};

static_assert(sizeof(GrainArguments) == 136U, "Metal Grain argument layout must stay stable");

struct GrainLatticeGenerateArguments {
    GrainArguments grain;
    std::int32_t origin_x;
    std::int32_t origin_y;
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t octave;
};

static_assert(sizeof(GrainLatticeGenerateArguments) == 160U,
              "Metal Grain lattice generation argument layout must stay stable");

struct GrainLatticeBlurArguments {
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t radius;
    std::uint32_t vertical;
    float sigma;
};

static_assert(sizeof(GrainLatticeBlurArguments) == 20U,
              "Metal Grain lattice blur argument layout must stay stable");

struct GrainLatticeInfo {
    std::int32_t origin_x;
    std::int32_t origin_y;
    std::uint32_t width;
    std::uint32_t height;
    float diameter;
};

static_assert(sizeof(GrainLatticeInfo) == 20U, "Metal Grain lattice info layout must stay stable");

struct GrainRenderArguments {
    GrainArguments grain;
    GrainLatticeInfo lattices[3];
};

static_assert(sizeof(GrainRenderArguments) == 200U,
              "Metal Grain final argument layout must stay stable");

struct MistArguments {
    std::int32_t data_x;
    std::int32_t data_y;
    std::int32_t window_x;
    std::int32_t window_y;
    std::int32_t width;
    std::int32_t height;
    std::uint32_t source_row_bytes;
    std::uint32_t destination_row_bytes;
    std::uint32_t working_mode;
    std::uint32_t diagnostic_view;
    float mix;
    std::int32_t mode;
    std::int32_t density;
    float diffusion;
    float bloom;
    float contrast;
    float texture;
    std::uint32_t alpha_association;
    std::uint32_t is_identity;
    std::uint32_t render_width;
    std::uint32_t render_height;
    std::uint32_t horizontal_radius;
    std::uint32_t vertical_radius;
    float accumulation_weight;
    float glow_radius_base;
    float glow_radius_tail;
    float veil_radius_base;
    float veil_radius_tail;
    float glow_energy;
    float veil_energy;
    float veil_contrast;
    float black_retention;
    float detail_fine_sigma;
    float detail_mid_sigma;
    float detail_edge_protection;
    float detail_strength;
};

static_assert(sizeof(MistArguments) == 144U, "Metal Mist argument layout must stay stable");

struct MistPyramidArguments {
    MistArguments base;
    std::int32_t source_x;
    std::int32_t source_y;
    std::uint32_t source_width;
    std::uint32_t source_height;
    std::uint32_t downsample;
    std::uint32_t output_width;
    std::uint32_t output_height;
};

static_assert(sizeof(MistPyramidArguments) == 172U, "Metal Mist pyramid argument layout must stay stable");

struct OpticalArguments {
    std::int32_t data_x;
    std::int32_t data_y;
    std::int32_t window_x;
    std::int32_t window_y;
    std::int32_t width;
    std::int32_t height;
    std::uint32_t source_row_bytes;
    std::uint32_t destination_row_bytes;
    std::uint32_t working_mode;
    std::uint32_t diagnostic_view;
    float mix;
    float highlight_response;
    std::uint32_t alpha_association;
    std::uint32_t tap_count;
    std::uint32_t render_width;
    std::uint32_t render_height;
    float blur_radius;
    float anamorphism;
    float bokeh_bias;
    float cat_eye;
    float vignetting;
    float coma;
    float astigmatism;
    float field_curvature;
    float chromatic_aberration;
    std::uint32_t lens_profile;
    std::uint32_t half_width;
    std::uint32_t half_height;
    std::uint32_t quarter_width;
    std::uint32_t quarter_height;
    std::uint32_t eighth_width;
    std::uint32_t eighth_height;
    std::uint32_t half_offset;
    std::uint32_t quarter_offset;
    std::uint32_t eighth_offset;
    std::uint32_t downsample_level;
};

struct OpticalPoint {
    float x;
    float y;
    float weight;
    float padding;
};

static_assert(sizeof(OpticalArguments) == 144U, "Metal Optical argument layout must stay stable");
static_assert(sizeof(OpticalPoint) == 16U, "Metal Optical point layout must stay stable");

struct LensV2Arguments {
    std::int32_t data_x;
    std::int32_t data_y;
    std::int32_t window_x;
    std::int32_t window_y;
    std::int32_t width;
    std::int32_t height;
    std::uint32_t source_row_bytes;
    std::uint32_t destination_row_bytes;
    std::uint32_t working_mode;
    std::uint32_t diagnostic_view;
    float mix;
    float amount;
    float threshold;
    float spread;
    float blur;
    float chroma;
    float anamorphism;
    std::uint32_t alpha_association;
    std::uint32_t render_width;
    std::uint32_t render_height;
    std::int32_t source_mode;
    std::int32_t source_metric;
    float source_gamma;
    float source_smoothness;
    float source_morphology;
    float manual_x;
    float manual_y;
    float manual_size;
    float manual_intensity;
    std::int32_t manual_color;
    float center_x;
    float center_y;
    float background_adaptation;
    float veil;
    std::int32_t element_solo;
    std::uint32_t has_matte;
    std::uint32_t matte_format;
    std::uint32_t matte_alpha_association;
    std::int32_t matte_x;
    std::int32_t matte_y;
    std::int32_t matte_width;
    std::int32_t matte_height;
    std::uint32_t matte_row_bytes;
    float render_scale_x;
    float render_scale_y;
    std::uint32_t tile_columns;
    std::uint32_t tile_rows;
    std::uint32_t half_width;
    std::uint32_t half_height;
    std::uint32_t lens_model;
    std::uint32_t use_half_source;
    std::uint32_t projection_downsample;
    std::uint32_t projection_width;
    std::uint32_t projection_height;
};

static_assert(sizeof(LensV2Arguments) == 216U, "Metal Lens v2 arguments layout must stay stable");

struct LensElementGpu {
    float axis_position;
    float magnification;
    float defocus;
    float aperture_clip;
    float ring_profile;
    float radial_falloff;
    float tint_r;
    float tint_g;
    float tint_b;
    float dispersion;
    float energy;
    float background_falloff;
    float streak_aspect;
    float pattern_retention;
    std::uint32_t shape;
    std::uint32_t padding;
};

static_assert(sizeof(LensElementGpu) == 64U, "Metal Lens element layout must stay stable");

struct GaussianPair {
    float weight;
    float offset;
};

static_assert(sizeof(GaussianPair) == 8U, "Metal Gaussian pair layout must stay stable");

struct ClearArguments {
    std::uint32_t width;
    std::uint32_t height;
};

static_assert(sizeof(ClearArguments) == 8U, "Metal clear argument layout must stay stable");

std::mutex pipeline_mutex;
std::map<std::pair<void*, std::string>, id<MTLComputePipelineState>> pipelines;
std::map<void*, id<MTLLibrary>> libraries;

NSString* shaderLibraryPath()
{
    const char* configured_path = std::getenv("CBEF_METALLIB_PATH");
    if (configured_path != nullptr && configured_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:configured_path];
        if (path != nil && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return path;
        }
    }

    Dl_info image_info{};
    if (dladdr(reinterpret_cast<const void*>(&shaderLibraryPath), &image_info) == 0 ||
        image_info.dli_fname == nullptr) {
        return nil;
    }
    NSString* image_path = [NSString stringWithUTF8String:image_info.dli_fname];
    if (image_path == nil) return nil;
    NSString* image_directory = [image_path stringByDeletingLastPathComponent];
    NSArray<NSString*>* candidates = @[
        [image_directory stringByAppendingPathComponent:@"../Resources/CBEFFilmEffects.metallib"],
        [image_directory stringByAppendingPathComponent:@"CBEFFilmEffects.metallib"],
        [image_directory stringByAppendingPathComponent:
                              @"../CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib"],
    ];
    NSFileManager* file_manager = [NSFileManager defaultManager];
    for (NSString* candidate in candidates) {
        if ([file_manager fileExistsAtPath:candidate]) {
            return [candidate stringByStandardizingPath];
        }
    }
    return nil;
}

RenderSubmission failed(Error error)
{
    return RenderSubmission{SubmissionKind::Failed, error};
}

id<MTLComputePipelineState> pipelineFor(id<MTLDevice> device, const char* function_name)
{
    std::lock_guard<std::mutex> lock(pipeline_mutex);
    const std::pair<void*, std::string> key{static_cast<void*>(device), function_name};
    const auto existing = pipelines.find(key);
    if (existing != pipelines.end()) {
        return existing->second;
    }

    id<MTLLibrary> library = nil;
    const auto library_existing = libraries.find(static_cast<void*>(device));
    if (library_existing != libraries.end()) {
        library = library_existing->second;
    } else {
        NSString* library_path = shaderLibraryPath();
        if (library_path == nil) {
            return nil;
        }
        NSURL* library_url = [NSURL fileURLWithPath:library_path];
        NSError* error = nil;
        library = [device newLibraryWithURL:library_url error:&error];
        if (library == nil) {
            return nil;
        }
        libraries.emplace(static_cast<void*>(device), library);
    }
    id<MTLFunction> function = [library newFunctionWithName:@(function_name)];
    if (function == nil) {
        return nil;
    }
    NSError* error = nil;
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
    [function release];
    if (pipeline != nil) {
        pipelines.emplace(key, pipeline);
    }
    return pipeline;
}

std::vector<float> gaussianKernel(float sigma)
{
    if (sigma <= 1.0e-6F) return {1.0F};
    const int radius = static_cast<int>(std::ceil(3.0F * sigma));
    std::vector<float> weights(static_cast<std::size_t>(radius * 2 + 1));
    float total = 0.0F;
    for (int tap = -radius; tap <= radius; ++tap) {
        const float value = std::exp(-0.5F * static_cast<float>(tap * tap) / (sigma * sigma));
        weights[static_cast<std::size_t>(tap + radius)] = value;
        total += value;
    }
    for (float& value : weights) value /= total;
    return weights;
}

std::vector<GaussianPair> gaussianLinearPairs(const std::vector<float>& weights)
{
    const std::size_t radius = weights.size() / 2U;
    std::vector<GaussianPair> pairs;
    pairs.reserve(1U + (radius + 1U) / 2U);
    pairs.push_back({weights[radius], 0.0F});
    for (std::size_t offset = 1U; offset <= radius; offset += 2U) {
        if (offset + 1U <= radius) {
            const float first = weights[radius + offset];
            const float second = weights[radius + offset + 1U];
            const float combined = first + second;
            pairs.push_back({combined, (first * static_cast<float>(offset) +
                                        second * static_cast<float>(offset + 1U)) /
                                           std::max(combined, 1.0e-20F)});
        } else {
            pairs.push_back({weights[radius + offset], static_cast<float>(offset)});
        }
    }
    return pairs;
}

bool encode2D(id<MTLCommandBuffer> command_buffer, id<MTLComputePipelineState> pipeline, int width, int height,
              const std::vector<std::pair<id<MTLBuffer>, NSUInteger>>& buffers, const void* arguments,
              NSUInteger argument_length)
{
    id<MTLComputeCommandEncoder> encoder = [command_buffer computeCommandEncoder];
    if (encoder == nil) return false;
    [encoder setComputePipelineState:pipeline];
    for (std::size_t index = 0; index < buffers.size(); ++index) {
        [encoder setBuffer:buffers[index].first offset:buffers[index].second atIndex:index];
    }
    [encoder setBytes:arguments length:argument_length atIndex:buffers.size()];
    const NSUInteger thread_width = std::min<NSUInteger>(pipeline.threadExecutionWidth, static_cast<NSUInteger>(width));
    if (thread_width == 0U || height <= 0) {
        [encoder endEncoding];
        return false;
    }
    [encoder dispatchThreadgroups:MTLSizeMake((static_cast<NSUInteger>(width) + thread_width - 1U) / thread_width,
                                               static_cast<NSUInteger>(height), 1U)
             threadsPerThreadgroup:MTLSizeMake(thread_width, 1U, 1U)];
    [encoder memoryBarrierWithScope:MTLBarrierScopeBuffers];
    [encoder endEncoding];
    return true;
}

bool encode2DTextured(id<MTLCommandBuffer> command_buffer, id<MTLComputePipelineState> pipeline, int width, int height,
                      const std::vector<id<MTLTexture>>& textures,
                      const std::vector<std::pair<id<MTLBuffer>, NSUInteger>>& buffers, const void* arguments,
                      NSUInteger argument_length)
{
    id<MTLComputeCommandEncoder> encoder = [command_buffer computeCommandEncoder];
    if (encoder == nil) return false;
    [encoder setComputePipelineState:pipeline];
    for (std::size_t index = 0; index < textures.size(); ++index) {
        [encoder setTexture:textures[index] atIndex:index];
    }
    for (std::size_t index = 0; index < buffers.size(); ++index) {
        [encoder setBuffer:buffers[index].first offset:buffers[index].second atIndex:index];
    }
    [encoder setBytes:arguments length:argument_length atIndex:buffers.size()];
    const NSUInteger thread_width = std::min<NSUInteger>(pipeline.threadExecutionWidth, static_cast<NSUInteger>(width));
    if (thread_width == 0U || height <= 0) {
        [encoder endEncoding];
        return false;
    }
    [encoder dispatchThreadgroups:MTLSizeMake((static_cast<NSUInteger>(width) + thread_width - 1U) / thread_width,
                                               static_cast<NSUInteger>(height), 1U)
             threadsPerThreadgroup:MTLSizeMake(thread_width, 1U, 1U)];
    [encoder memoryBarrierWithScope:MTLBarrierScopeBuffers | MTLBarrierScopeTextures];
    [encoder endEncoding];
    return true;
}

bool fitsBuffer(const FrameSurface& surface, id<MTLBuffer> buffer)
{
    if (surface.byte_offset % alignof(float) != 0U || surface.data_window.height <= 0 ||
        surface.row_bytes > std::numeric_limits<std::size_t>::max() /
                                static_cast<std::size_t>(surface.data_window.height)) {
        return false;
    }
    const std::size_t extent = static_cast<std::size_t>(surface.data_window.height - 1) * surface.row_bytes +
                               static_cast<std::size_t>(surface.data_window.width) * sizeof(float) * 4U;
    const std::size_t buffer_length = static_cast<std::size_t>(buffer.length);
    return surface.byte_offset <= buffer_length && extent <= buffer_length - surface.byte_offset;
}

// Metal encoders retain resources until their command buffer completes. Keep the
// owning retain local to submit so every temporary allocation is released on
// both success and every early-return path without adding completion handlers.
class ScopedMTLBuffer {
public:
    explicit ScopedMTLBuffer(id<MTLBuffer> buffer = nil, bool owns = true) : buffer_(buffer), owns_(owns) {}
    ~ScopedMTLBuffer() { if (owns_) [buffer_ release]; }

    ScopedMTLBuffer(const ScopedMTLBuffer&) = delete;
    ScopedMTLBuffer& operator=(const ScopedMTLBuffer&) = delete;

    id<MTLBuffer> get() const { return buffer_; }
    operator id<MTLBuffer>() const { return buffer_; }

private:
    id<MTLBuffer> buffer_;
    bool owns_;
};

class ScopedMTLTexture {
public:
    explicit ScopedMTLTexture(id<MTLTexture> texture = nil) : texture_(texture) {}
    ~ScopedMTLTexture() { [texture_ release]; }

    ScopedMTLTexture(const ScopedMTLTexture&) = delete;
    ScopedMTLTexture& operator=(const ScopedMTLTexture&) = delete;

    id<MTLTexture> get() const { return texture_; }
    operator id<MTLTexture>() const { return texture_; }

private:
    id<MTLTexture> texture_;
};

id<MTLTexture> linearTextureForBuffer(id<MTLDevice> device, id<MTLBuffer> buffer, int width, int height)
{
    if (device == nil || buffer == nil || width <= 0 || height <= 0) return nil;
    const NSUInteger row_bytes = static_cast<NSUInteger>(width) * sizeof(float) * 4U;
    const NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatRGBA32Float];
    const NSUInteger required_alignment = std::max<NSUInteger>(alignment, 256U);
    if (alignment == 0U || row_bytes % required_alignment != 0U) return nil;
    MTLTextureDescriptor* descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                            width:static_cast<NSUInteger>(width)
                                                           height:static_cast<NSUInteger>(height)
                                                        mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    descriptor.storageMode = MTLStorageModeShared;
    return [buffer newTextureWithDescriptor:descriptor offset:0U bytesPerRow:row_bytes];
}

std::size_t alignTextureRowBytes(std::size_t row_bytes, std::size_t alignment)
{
    const std::size_t required = std::max<std::size_t>(alignment, 256U);
    if (required == 0U || row_bytes > std::numeric_limits<std::size_t>::max() - (required - 1U)) return 0U;
    return ((row_bytes + required - 1U) / required) * required;
}

id<MTLTexture> alignedRG32TextureForBuffer(id<MTLDevice> device, id<MTLBuffer> buffer, int width, int height,
                                           std::size_t row_bytes, std::size_t offset = 0U)
{
    if (device == nil || buffer == nil || width <= 0 || height <= 0 || row_bytes == 0U) return nil;
    const NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatRG32Float];
    const NSUInteger required_alignment = std::max<NSUInteger>(alignment, 256U);
    if (alignment == 0U || row_bytes % required_alignment != 0U ||
        offset % std::max<NSUInteger>(alignment, 8U) != 0U ||
        offset > static_cast<std::size_t>(buffer.length) ||
        row_bytes > (static_cast<std::size_t>(buffer.length) - offset) /
                         static_cast<std::size_t>(height)) {
        return nil;
    }
    MTLTextureDescriptor* descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG32Float
                                                            width:static_cast<NSUInteger>(width)
                                                           height:static_cast<NSUInteger>(height)
                                                        mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    descriptor.storageMode = MTLStorageModeShared;
    return [buffer newTextureWithDescriptor:descriptor offset:static_cast<NSUInteger>(offset)
                                  bytesPerRow:static_cast<NSUInteger>(row_bytes)];
}


}

MetalRenderBackend::MetalRenderBackend(void* command_queue)
    : command_queue_(command_queue)
{
}

BackendKind MetalRenderBackend::kind() const
{
    return BackendKind::Metal;
}

RenderSubmission MetalRenderBackend::submit(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    if (command_queue_ == nullptr) {
        return failed(Error::BackendUnavailable);
    }
    id<MTLCommandQueue> queue = reinterpret_cast<id<MTLCommandQueue>>(command_queue_);
    id<MTLBuffer> source = reinterpret_cast<id<MTLBuffer>>(request.source.data);
    id<MTLBuffer> destination = reinterpret_cast<id<MTLBuffer>>(request.destination.data);
    if (source == nil || destination == nil || queue.device == nil) {
        return failed(Error::BackendUnavailable);
    }
    if (!fitsBuffer(request.source, source) || !fitsBuffer(request.destination, destination) ||
        request.source.row_bytes > std::numeric_limits<std::uint32_t>::max()) {
        return failed(Error::InvalidStride);
    }

    id<MTLCommandBuffer> command_buffer = [queue commandBuffer];
    if (command_buffer == nil) {
        return failed(Error::CommandEncodingFailed);
    }
    detail::FrameArena* arena = detail::sharedFrameArenaFor(queue);
    detail::FrameArena::Scope arena_scope = arena != nullptr ? arena->begin() : detail::FrameArena::Scope();

    if (request.effect == EffectId::FilmGrain) {
        const GrainArguments arguments = {
            request.source.data_window.x,
            request.source.data_window.y,
            request.render_window.x1,
            request.render_window.y1,
            request.render_window.x2 - request.render_window.x1,
            request.render_window.y2 - request.render_window.y1,
            request.source.data_window.height,
            static_cast<std::uint32_t>(request.source.row_bytes),
            static_cast<std::uint32_t>(request.destination.row_bytes),
            static_cast<std::uint32_t>(plan.workingMode()),
            static_cast<std::uint32_t>(plan.diagnosticView()),
            plan.mixAmount(),
            plan.grain().format,
            plan.grain().amount,
            plan.grain().size,
            plan.grain().softness,
            plan.grain().chroma,
            plan.grain().shadow,
            plan.grain().midtone,
            plan.grain().highlight,
            plan.grain().seed,
            plan.grain().frame,
            static_cast<std::uint32_t>(request.alpha_association),
            plan.is_identity ? 1U : 0U,
            plan.grain().stock_response,
            plan.grain().scan_sampling,
            plan.grain().processing_modifier,
            plan.grain().film_resolution,
            plan.grain().clump,
            plan.grain().exposure_bias,
            1080.0F / static_cast<float>(std::max(request.source.data_window.height, 1)) *
                static_cast<float>(request.render_scale.y) * plan.grain().scan_sampling,
        };
        auto encode_direct = [&]() -> RenderSubmission {
            id<MTLComputePipelineState> pipeline = pipelineFor(queue.device, "cbef_grain_reference_v2");
            if (pipeline == nil) return failed(Error::PipelineCreationFailed);
            if (!encode2D(command_buffer, pipeline, arguments.width, arguments.height,
                          {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                          &arguments, sizeof(arguments))) {
                return failed(Error::CommandEncodingFailed);
            }
            arena_scope.commit(command_buffer);
            [command_buffer commit];
            return RenderSubmission{SubmissionKind::Enqueued, Error::None};
        };
        // Small windows use the exact per-pixel reference kernel. Larger windows
        // use the stationary packed lattice below to keep the same field while
        // amortizing Philox and Gaussian work.
        if (arguments.width <= 512 && arguments.height <= 512) return encode_direct();

        const std::array<float, 5> diameters = {1.80F, 1.10F, 1.35F, 0.80F, 2.45F};
        const std::array<std::array<float, 3>, 3> record_diameters = {{
            {1.00F, 1.00F, 1.00F},
            {1.00F, 1.00F, 1.00F},
            {1.08F, 1.00F, 0.94F},
        }};
        const int format = std::clamp(plan.grain().format, 0, 4);
        const int stock = std::clamp(plan.grain().stock_response, 0, 2);
        const float scale = 1080.0F / static_cast<float>(request.source.data_window.height) *
                            static_cast<float>(request.render_scale.y) * plan.grain().scan_sampling;
        const float base_diameter = diameters[static_cast<std::size_t>(format)] * (plan.grain().size / 100.0F);
        id<MTLComputePipelineState> generate = pipelineFor(queue.device, "cbef_grain_lattice_generate");
        id<MTLComputePipelineState> blur = pipelineFor(queue.device, "cbef_grain_lattice_blur");
        id<MTLComputePipelineState> final = pipelineFor(queue.device, "cbef_grain_final");
        if (generate == nil || blur == nil || final == nil) return failed(Error::PipelineCreationFailed);
        constexpr int kTileWidth = 640;
        constexpr int kTileHeight = 512;
        struct GrainTileWork {
            GrainArguments arguments;
            std::array<GrainLatticeInfo, 3> lattices;
        };
        std::vector<GrainTileWork> tiles;
        const int tile_columns = (arguments.width + kTileWidth - 1) / kTileWidth;
        const int tile_rows = (arguments.height + kTileHeight - 1) / kTileHeight;
        try {
            tiles.reserve(static_cast<std::size_t>(tile_columns) * static_cast<std::size_t>(tile_rows));
        } catch (const std::bad_alloc&) {
            return failed(Error::TemporaryAllocationFailed);
        }
        std::array<std::size_t, 3> maximum_lattice_lengths{};
        for (int tile_y = request.render_window.y1; tile_y < request.render_window.y2; tile_y += kTileHeight) {
            for (int tile_x = request.render_window.x1; tile_x < request.render_window.x2; tile_x += kTileWidth) {
                const int tile_x2 = std::min(tile_x + kTileWidth, request.render_window.x2);
                const int tile_y2 = std::min(tile_y + kTileHeight, request.render_window.y2);
                GrainArguments tile_arguments = arguments;
                tile_arguments.window_x = tile_x;
                tile_arguments.window_y = tile_y;
                tile_arguments.width = tile_x2 - tile_x;
                tile_arguments.height = tile_y2 - tile_y;
                std::array<GrainLatticeInfo, 3> lattice_info{};
                bool supported = true;
                for (int octave = 0; octave < 3; ++octave) {
                    const float diameter = base_diameter * static_cast<float>(1 << octave);
                    const float sigma = 1.0F;
                    const std::int64_t radius = sigma > 1.0e-8F ? static_cast<std::int64_t>(std::ceil(4.0F * sigma)) : 0;
                    const float min_x = ((static_cast<float>(tile_x - request.source.data_window.x) + 0.5F) * scale) / diameter;
                    const float max_x = ((static_cast<float>(tile_x2 - 1 - request.source.data_window.x) + 0.5F) * scale) / diameter;
                    const float min_y = ((static_cast<float>(tile_y - request.source.data_window.y) + 0.5F) * scale) / diameter;
                    const float max_y = ((static_cast<float>(tile_y2 - 1 - request.source.data_window.y) + 0.5F) * scale) / diameter;
                    const float rotated_min_x = std::min({0.9238795325F * min_x + 0.3826834324F * min_y,
                                                          0.9238795325F * min_x + 0.3826834324F * max_y,
                                                          0.9238795325F * max_x + 0.3826834324F * min_y,
                                                          0.9238795325F * max_x + 0.3826834324F * max_y});
                    const float rotated_max_x = std::max({0.9238795325F * min_x + 0.3826834324F * min_y,
                                                          0.9238795325F * min_x + 0.3826834324F * max_y,
                                                          0.9238795325F * max_x + 0.3826834324F * min_y,
                                                          0.9238795325F * max_x + 0.3826834324F * max_y});
                    const float rotated_min_y = std::min({-0.3826834324F * min_x + 0.9238795325F * min_y,
                                                          -0.3826834324F * min_x + 0.9238795325F * max_y,
                                                          -0.3826834324F * max_x + 0.9238795325F * min_y,
                                                          -0.3826834324F * max_x + 0.9238795325F * max_y});
                    const float rotated_max_y = std::max({-0.3826834324F * min_x + 0.9238795325F * min_y,
                                                          -0.3826834324F * min_x + 0.9238795325F * max_y,
                                                          -0.3826834324F * max_x + 0.9238795325F * min_y,
                                                          -0.3826834324F * max_x + 0.9238795325F * max_y});
                    float lattice_min_x = std::numeric_limits<float>::infinity();
                    float lattice_max_x = -std::numeric_limits<float>::infinity();
                    float lattice_min_y = std::numeric_limits<float>::infinity();
                    float lattice_max_y = -std::numeric_limits<float>::infinity();
                    for (float record_diameter : record_diameters[static_cast<std::size_t>(stock)]) {
                        lattice_min_x = std::min(lattice_min_x, rotated_min_x / record_diameter);
                        lattice_max_x = std::max(lattice_max_x, rotated_max_x / record_diameter);
                        lattice_min_y = std::min(lattice_min_y, rotated_min_y / record_diameter);
                        lattice_max_y = std::max(lattice_max_y, rotated_max_y / record_diameter);
                    }
                    const std::int64_t required_min_x = static_cast<std::int64_t>(std::floor(lattice_min_x));
                    const std::int64_t required_max_x = static_cast<std::int64_t>(std::floor(lattice_max_x)) + 1;
                    const std::int64_t required_min_y = static_cast<std::int64_t>(std::floor(lattice_min_y));
                    const std::int64_t required_max_y = static_cast<std::int64_t>(std::floor(lattice_max_y)) + 1;
                    const std::int64_t origin_x = required_min_x - radius;
                    const std::int64_t origin_y = required_min_y - radius;
                    const std::int64_t lattice_width = required_max_x + radius - origin_x + 1;
                    const std::int64_t lattice_height = required_max_y + radius - origin_y + 1;
                    if (radius < 0 || origin_x < std::numeric_limits<std::int32_t>::min() || origin_x > std::numeric_limits<std::int32_t>::max() ||
                        origin_y < std::numeric_limits<std::int32_t>::min() || origin_y > std::numeric_limits<std::int32_t>::max() ||
                        lattice_width <= 2 * radius || lattice_height <= 2 * radius ||
                        lattice_width > std::numeric_limits<std::uint32_t>::max() || lattice_height > std::numeric_limits<std::uint32_t>::max()) {
                        supported = false;
                        break;
                    }
                    const std::size_t cells = static_cast<std::size_t>(lattice_width) * static_cast<std::size_t>(lattice_height);
                    if (cells > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
                        supported = false;
                        break;
                    }
                    const std::size_t bytes = cells * sizeof(float) * 4U;
                    lattice_info[static_cast<std::size_t>(octave)] = {static_cast<std::int32_t>(origin_x), static_cast<std::int32_t>(origin_y),
                                                                        static_cast<std::uint32_t>(lattice_width), static_cast<std::uint32_t>(lattice_height), diameter};
                    maximum_lattice_lengths[static_cast<std::size_t>(octave)] =
                        std::max(maximum_lattice_lengths[static_cast<std::size_t>(octave)], bytes);
                }
                if (!supported) return failed(Error::TemporaryAllocationFailed);
                try {
                    tiles.push_back(GrainTileWork{tile_arguments, lattice_info});
                } catch (const std::bad_alloc&) {
                    return failed(Error::TemporaryAllocationFailed);
                }
            }
        }
        std::array<ScopedMTLBuffer, 9> buffers = {
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[0]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[1]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[2]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[0]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[1]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[2]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[0]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[1]), false),
            ScopedMTLBuffer(arena_scope.acquire(queue.device, maximum_lattice_lengths[2]), false)};
        for (const ScopedMTLBuffer& buffer : buffers) {
            if (buffer.get() == nil) return failed(Error::TemporaryAllocationFailed);
        }
        for (const GrainTileWork& tile : tiles) {
            const GrainArguments& tile_arguments = tile.arguments;
            const std::array<GrainLatticeInfo, 3>& lattice_info = tile.lattices;
                for (int octave = 0; octave < 3; ++octave) {
                    const GrainLatticeInfo& info = lattice_info[static_cast<std::size_t>(octave)];
                    const float sigma = 1.0F;
                    const std::uint32_t radius = sigma > 1.0e-8F ? static_cast<std::uint32_t>(std::ceil(4.0F * sigma)) : 0U;
                    GrainLatticeGenerateArguments generate_arguments = {tile_arguments, info.origin_x, info.origin_y, info.width, info.height,
                                                                        static_cast<std::uint32_t>(octave)};
                    const auto raw = buffers[static_cast<std::size_t>(octave)].get();
                    const auto horizontal = buffers[static_cast<std::size_t>(octave + 3)].get();
                    const auto blurred = buffers[static_cast<std::size_t>(octave + 6)].get();
                    if (!encode2D(command_buffer, generate, static_cast<int>(info.width), static_cast<int>(info.height), {{raw, 0U}},
                                  &generate_arguments, sizeof(generate_arguments))) return failed(Error::CommandEncodingFailed);
                    const GrainLatticeBlurArguments horizontal_arguments = {info.width, info.height, radius, 0U, sigma};
                    const GrainLatticeBlurArguments vertical_arguments = {info.width, info.height, radius, 1U, sigma};
                    if (!encode2D(command_buffer, blur, static_cast<int>(info.width), static_cast<int>(info.height), {{raw, 0U}, {horizontal, 0U}},
                                  &horizontal_arguments, sizeof(horizontal_arguments)) ||
                        !encode2D(command_buffer, blur, static_cast<int>(info.width), static_cast<int>(info.height), {{horizontal, 0U}, {blurred, 0U}},
                                  &vertical_arguments, sizeof(vertical_arguments))) return failed(Error::CommandEncodingFailed);
                }
                GrainRenderArguments render_arguments = {tile_arguments, {}};
                for (std::size_t index = 0; index < lattice_info.size(); ++index) render_arguments.lattices[index] = lattice_info[index];
                if (!encode2D(command_buffer, final, tile_arguments.width, tile_arguments.height,
                              {{source, request.source.byte_offset}, {destination, request.destination.byte_offset},
                               {buffers[6].get(), 0U}, {buffers[7].get(), 0U}, {buffers[8].get(), 0U}},
                              &render_arguments, sizeof(render_arguments))) return failed(Error::CommandEncodingFailed);
        }
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }

    if (request.effect == EffectId::MistDiffusion) {
        const int width = request.source.data_window.width;
        const int height = request.source.data_window.height;
        const int render_width = request.render_window.x2 - request.render_window.x1;
        const int render_height = request.render_window.y2 - request.render_window.y1;
        const int grade = std::clamp(plan.mist().grade, 0, 4);
        const float energy_factor = std::array<float, 5>{0.25F, 0.50F, 0.75F, 1.00F, 1.20F}[
            static_cast<std::size_t>(grade)];
        const float veil_amount = plan.mist().veil / 100.0F * energy_factor;
        const float glow_amount = plan.mist().glow / 100.0F * energy_factor;
        const float contrast_slope = (veil_amount > 0.0F || plan.mist().contrast > 0.0F)
                                         ? std::max(0.20F, 1.0F - energy_factor * plan.mist().contrast /
                                                               plan.mist().veil_contrast)
                                         : 1.0F;
        const float texture = plan.mist().detail_retention / 100.0F;
        const MistArguments base = {
            request.source.data_window.x,
            request.source.data_window.y,
            request.render_window.x1,
            request.render_window.y1,
            width,
            height,
            static_cast<std::uint32_t>(request.source.row_bytes),
            static_cast<std::uint32_t>(request.destination.row_bytes),
            static_cast<std::uint32_t>(plan.workingMode()),
            static_cast<std::uint32_t>(plan.diagnosticView()),
            plan.mixAmount(),
            plan.mist().mode,
            plan.mist().density,
            veil_amount,
            glow_amount,
            contrast_slope,
            texture,
            static_cast<std::uint32_t>(request.alpha_association),
            plan.is_identity ? 1U : 0U,
            static_cast<std::uint32_t>(render_width),
            static_cast<std::uint32_t>(render_height),
            0U,
            0U,
            0.0F,
            plan.mist().glow_radius_base,
            plan.mist().glow_radius_tail,
            plan.mist().veil_radius_base,
            plan.mist().veil_radius_tail,
            plan.mist().glow_energy,
            plan.mist().veil_energy,
            plan.mist().veil_contrast,
            plan.mist().black_retention,
            plan.mist().detail_fine_sigma,
            plan.mist().detail_mid_sigma,
            plan.mist().detail_edge_protection,
            plan.mist().detail_strength,
        };
        if (plan.is_identity) {
            id<MTLComputePipelineState> copy = pipelineFor(queue.device, "cbef_mist_copy");
            if (copy == nil) return failed(Error::PipelineCreationFailed);
            if (!encode2D(command_buffer, copy, render_width, render_height,
                          {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                          &base, sizeof(base))) {
                return failed(Error::CommandEncodingFailed);
            }
            arena_scope.commit(command_buffer);
            [command_buffer commit];
            return RenderSubmission{SubmissionKind::Enqueued, Error::None};
        }
        // UHD uses a shared three-pixel scatter pyramid. The CPU reference remains the
        // exact path below for small/cropped frames; this path keeps all seven Mist
        // contributions at one-third resolution and reconstructs them in one final pass.
        if (render_width == width && render_height == height && width >= 1024 && height >= 576) {
            constexpr std::uint32_t kDownsample = 3U;
            const int level_width = (width + static_cast<int>(kDownsample) - 1) / static_cast<int>(kDownsample);
            const int level_height = (height + static_cast<int>(kDownsample) - 1) / static_cast<int>(kDownsample);
            const std::size_t level_pixels = static_cast<std::size_t>(level_width) * static_cast<std::size_t>(level_height);
            if (level_pixels <= std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
                const std::size_t level_length = level_pixels * sizeof(float) * 4U;
                ScopedMTLBuffer positive(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLBuffer highlighted(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLBuffer horizontal(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLBuffer diffusion(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLBuffer bloom(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLBuffer detail_fine(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLBuffer detail_mid(arena_scope.acquire(queue.device, level_length), false);
                ScopedMTLTexture positive_texture(linearTextureForBuffer(queue.device, positive, level_width, level_height));
                ScopedMTLTexture diffusion_texture(linearTextureForBuffer(queue.device, diffusion, level_width, level_height));
                ScopedMTLTexture bloom_texture(linearTextureForBuffer(queue.device, bloom, level_width, level_height));
                ScopedMTLTexture detail_fine_texture(linearTextureForBuffer(queue.device, detail_fine, level_width, level_height));
                ScopedMTLTexture detail_mid_texture(linearTextureForBuffer(queue.device, detail_mid, level_width, level_height));
                id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_mist_prepare_pyramid");
                id<MTLComputePipelineState> horizontal_pipeline = pipelineFor(queue.device, "cbef_mist_horizontal");
                id<MTLComputePipelineState> vertical = pipelineFor(queue.device, "cbef_mist_vertical");
                id<MTLComputePipelineState> finalize = pipelineFor(queue.device, "cbef_mist_finalize_pyramid");
                const bool supported = positive.get() != nil && highlighted.get() != nil && horizontal.get() != nil &&
                                       diffusion.get() != nil && bloom.get() != nil && detail_fine.get() != nil &&
                                       detail_mid.get() != nil && positive_texture.get() != nil && diffusion_texture.get() != nil &&
                                       bloom_texture.get() != nil && detail_fine_texture.get() != nil && detail_mid_texture.get() != nil &&
                                       prepare != nil && horizontal_pipeline != nil && vertical != nil && finalize != nil;
                if (supported) {
                    MistArguments level_base = base;
                    level_base.data_x = 0;
                    level_base.data_y = 0;
                    level_base.window_x = 0;
                    level_base.window_y = 0;
                    level_base.width = level_width;
                    level_base.height = level_height;
                    level_base.render_width = static_cast<std::uint32_t>(level_width);
                    level_base.render_height = static_cast<std::uint32_t>(level_height);
                    level_base.is_identity = 0U;
                    MistPyramidArguments pyramid_arguments{level_base, request.source.data_window.x, request.source.data_window.y,
                                                           static_cast<std::uint32_t>(width), static_cast<std::uint32_t>(height),
                                                           kDownsample, static_cast<std::uint32_t>(width), static_cast<std::uint32_t>(height)};
                    bool encoded = encode2D(command_buffer, prepare, level_width, level_height,
                                            {{source, request.source.byte_offset}, {positive, 0U}, {highlighted, 0U}},
                                            &pyramid_arguments, sizeof(pyramid_arguments));
                    std::memset(diffusion.get().contents, 0, level_length);
                    std::memset(bloom.get().contents, 0, level_length);
                    std::memset(detail_fine.get().contents, 0, level_length);
                    std::memset(detail_mid.get().contents, 0, level_length);
                    const float level_scale = static_cast<float>(kDownsample);
                    const float scale_x = static_cast<float>(request.render_scale.y / request.render_scale.x);
                    auto enqueue_low = [&](id<MTLBuffer> input, id<MTLBuffer> accumulation, float sigma_y,
                                           float accumulation_weight) -> bool {
                        const std::vector<float> horizontal_weights = gaussianKernel(std::max(sigma_y / level_scale, 0.001F) * scale_x);
                        const std::vector<float> vertical_weights = gaussianKernel(std::max(sigma_y / level_scale, 0.001F));
                        ScopedMTLBuffer horizontal_weight(arena_scope.acquireBytes(queue.device, horizontal_weights.data(), horizontal_weights.size() * sizeof(float)), false);
                        ScopedMTLBuffer vertical_weight(arena_scope.acquireBytes(queue.device, vertical_weights.data(), vertical_weights.size() * sizeof(float)), false);
                        if (horizontal_weight.get() == nil || vertical_weight.get() == nil) return false;
                        MistArguments arguments = level_base;
                        arguments.horizontal_radius = static_cast<std::uint32_t>(horizontal_weights.size() / 2U);
                        arguments.vertical_radius = static_cast<std::uint32_t>(vertical_weights.size() / 2U);
                        arguments.accumulation_weight = accumulation_weight;
                        return encode2D(command_buffer, horizontal_pipeline, level_width, level_height,
                                        {{input, 0U}, {horizontal, 0U}, {horizontal_weight, 0U}}, &arguments, sizeof(arguments)) &&
                               encode2D(command_buffer, vertical, level_width, level_height,
                                        {{horizontal, 0U}, {accumulation, 0U}, {vertical_weight, 0U}}, &arguments, sizeof(arguments));
                    };
                    const float height_scale = static_cast<float>(height);
                    const float radius_factor = std::array<float, 5>{0.80F, 0.95F, 1.10F, 1.25F, 1.40F}[static_cast<std::size_t>(grade)];
                    const float profile_radius = plan.mist().profile == 1 ? 1.25F : 1.0F;
                    const float veil_radius = height_scale * ((0.10F + 1.40F * plan.mist().veil / 100.0F) / 100.0F) * radius_factor * profile_radius * plan.mist().veil_radius_base;
                    const float glow_radius = height_scale * ((0.10F + 1.40F * plan.mist().glow / 100.0F) / 100.0F) * radius_factor * profile_radius * plan.mist().glow_radius_base;
                    const float detail_scale = std::max(0.5F, height_scale / 256.0F);
                    encoded = encoded && enqueue_low(positive, diffusion, veil_radius, 0.70F) &&
                              enqueue_low(positive, diffusion, veil_radius * plan.mist().veil_radius_tail, 0.30F) &&
                              enqueue_low(highlighted, bloom, glow_radius, 0.65F) &&
                              enqueue_low(highlighted, bloom, glow_radius * plan.mist().glow_radius_tail, 0.35F) &&
                              enqueue_low(positive, detail_fine, plan.mist().detail_fine_sigma * detail_scale, 1.0F) &&
                              enqueue_low(positive, detail_mid, plan.mist().detail_mid_sigma * detail_scale, 1.0F);
                    encoded = encoded && encode2DTextured(command_buffer, finalize, width, height,
                                                          {positive_texture.get(), diffusion_texture.get(), bloom_texture.get(),
                                                           detail_fine_texture.get(), detail_mid_texture.get()},
                                                          {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                                                          &pyramid_arguments, sizeof(pyramid_arguments));
                    if (encoded) {
                        arena_scope.commit(command_buffer);
                        [command_buffer commit];
                        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
                    }
                }
            }
        }
        {
        const std::size_t pixel_count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
        if (pixel_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U) ||
            static_cast<std::size_t>(render_width) > std::numeric_limits<std::size_t>::max() /
                                                       static_cast<std::size_t>(render_height)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        const std::size_t sample_length = pixel_count * sizeof(float) * 4U;
        const std::size_t render_count = static_cast<std::size_t>(render_width) * static_cast<std::size_t>(render_height);
        if (render_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        const std::size_t accumulation_length = render_count * sizeof(float) * 4U;
        ScopedMTLBuffer positive(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLBuffer highlighted(arena_scope.acquire(queue.device, sample_length), false);
        if (render_width <= 0 || render_height <= 0) return failed(Error::TemporaryAllocationFailed);
        ScopedMTLBuffer horizontal(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLBuffer diffusion(arena_scope.acquire(queue.device, accumulation_length), false);
        ScopedMTLBuffer bloom(arena_scope.acquire(queue.device, accumulation_length), false);
        ScopedMTLBuffer detail_fine(arena_scope.acquire(queue.device, accumulation_length), false);
        ScopedMTLBuffer detail_mid(arena_scope.acquire(queue.device, accumulation_length), false);
        if (positive.get() == nil || highlighted.get() == nil || horizontal.get() == nil || diffusion.get() == nil ||
            bloom.get() == nil || detail_fine.get() == nil || detail_mid.get() == nil) {
            return failed(Error::TemporaryAllocationFailed);
        }
        ScopedMTLTexture positive_texture(linearTextureForBuffer(queue.device, positive, width, height));
        ScopedMTLTexture highlighted_texture(linearTextureForBuffer(queue.device, highlighted, width, height));
        ScopedMTLTexture horizontal_texture(linearTextureForBuffer(queue.device, horizontal, width, height));
        bool fast_path = false;
        id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_mist_prepare");
        id<MTLComputePipelineState> horizontal_pipeline = pipelineFor(queue.device, "cbef_mist_horizontal");
        id<MTLComputePipelineState> vertical = pipelineFor(queue.device, "cbef_mist_vertical");
        id<MTLComputePipelineState> finalize = pipelineFor(queue.device, "cbef_mist_finalize");
        id<MTLComputePipelineState> clear = fast_path ? pipelineFor(queue.device, "cbef_clear_float4") : nil;
        id<MTLComputePipelineState> horizontal_linear = fast_path ? pipelineFor(queue.device, "cbef_mist_horizontal_linear") : nil;
        id<MTLComputePipelineState> vertical_linear = fast_path ? pipelineFor(queue.device, "cbef_mist_vertical_linear") : nil;
        if (fast_path && (clear == nil || horizontal_linear == nil || vertical_linear == nil)) fast_path = false;
        if (prepare == nil || horizontal_pipeline == nil || vertical == nil || finalize == nil) {
            return failed(Error::PipelineCreationFailed);
        }
        MistArguments arguments = base;
        arguments.is_identity = fast_path ? 1U : 0U;
        if (fast_path) {
            const ClearArguments clear_arguments = {static_cast<std::uint32_t>(render_width),
                                                    static_cast<std::uint32_t>(render_height)};
            if (!encode2D(command_buffer, clear, render_width, render_height, {{diffusion, 0U}}, &clear_arguments,
                          sizeof(clear_arguments)) ||
                !encode2D(command_buffer, clear, render_width, render_height, {{bloom, 0U}}, &clear_arguments,
                           sizeof(clear_arguments)) ||
                !encode2D(command_buffer, clear, render_width, render_height, {{detail_fine, 0U}}, &clear_arguments,
                           sizeof(clear_arguments)) ||
                !encode2D(command_buffer, clear, render_width, render_height, {{detail_mid, 0U}}, &clear_arguments,
                           sizeof(clear_arguments))) {
                return failed(Error::CommandEncodingFailed);
            }
        } else {
            std::memset(diffusion.get().contents, 0, accumulation_length);
            std::memset(bloom.get().contents, 0, accumulation_length);
            std::memset(detail_fine.get().contents, 0, accumulation_length);
            std::memset(detail_mid.get().contents, 0, accumulation_length);
        }
        if (!encode2D(command_buffer, prepare, width, height,
                      {{source, request.source.byte_offset}, {positive, 0U}, {highlighted, 0U}},
                      &arguments, sizeof(arguments))) {
            return failed(Error::CommandEncodingFailed);
        }
        const float height_scale = static_cast<float>(height);
        const float radius_factor = std::array<float, 5>{0.80F, 0.95F, 1.10F, 1.25F, 1.40F}[
            static_cast<std::size_t>(grade)];
        const float profile_radius = plan.mist().profile == 1 ? 1.25F : 1.0F;
        const float veil_radius = height_scale * ((0.10F + 1.40F * plan.mist().veil / 100.0F) / 100.0F) *
                                  radius_factor * profile_radius * plan.mist().veil_radius_base;
        const float glow_radius = height_scale * ((0.10F + 1.40F * plan.mist().glow / 100.0F) / 100.0F) *
                                  radius_factor * profile_radius * plan.mist().glow_radius_base;
        const float scale_x = static_cast<float>(request.render_scale.y / request.render_scale.x);
        auto enqueue_blur = [&](id<MTLBuffer> input, id<MTLBuffer> accumulation, float sigma_y,
                                float accumulation_weight) -> bool {
            const float sigma_x = sigma_y * scale_x;
            const std::vector<float> horizontal_weights = gaussianKernel(sigma_x);
            const std::vector<float> vertical_weights = gaussianKernel(sigma_y);
            ScopedMTLBuffer horizontal_weight_buffer(
                arena_scope.acquireBytes(queue.device, horizontal_weights.data(), horizontal_weights.size() * sizeof(float)), false);
            ScopedMTLBuffer vertical_weight_buffer(
                arena_scope.acquireBytes(queue.device, vertical_weights.data(), vertical_weights.size() * sizeof(float)), false);
            if (horizontal_weight_buffer.get() == nil || vertical_weight_buffer.get() == nil) return false;
            arguments.horizontal_radius = static_cast<std::uint32_t>(horizontal_weights.size() / 2U);
            arguments.vertical_radius = static_cast<std::uint32_t>(vertical_weights.size() / 2U);
            arguments.accumulation_weight = accumulation_weight;
            if (fast_path) {
                const std::vector<GaussianPair> horizontal_pairs = gaussianLinearPairs(horizontal_weights);
                const std::vector<GaussianPair> vertical_pairs = gaussianLinearPairs(vertical_weights);
                ScopedMTLBuffer horizontal_pair_buffer(
                    arena_scope.acquireBytes(queue.device, horizontal_pairs.data(), horizontal_pairs.size() * sizeof(GaussianPair)), false);
                ScopedMTLBuffer vertical_pair_buffer(
                    arena_scope.acquireBytes(queue.device, vertical_pairs.data(), vertical_pairs.size() * sizeof(GaussianPair)), false);
                if (horizontal_pair_buffer.get() == nil || vertical_pair_buffer.get() == nil) return false;
                const id<MTLTexture> input_texture = input == positive ? positive_texture.get() : highlighted_texture.get();
                if (!encode2DTextured(command_buffer, horizontal_linear, width, height, {input_texture},
                                      {{horizontal, 0U}, {horizontal_pair_buffer, 0U}}, &arguments,
                                      sizeof(arguments)) ||
                    !encode2DTextured(command_buffer, vertical_linear, render_width, render_height,
                                      {horizontal_texture.get()}, {{accumulation, 0U}, {vertical_pair_buffer, 0U}},
                                      &arguments, sizeof(arguments))) {
                    return false;
                }
                return true;
            }
            const bool encoded =
                encode2D(command_buffer, horizontal_pipeline, width, height,
                         {{input, 0U}, {horizontal, 0U}, {horizontal_weight_buffer, 0U}}, &arguments,
                         sizeof(arguments)) &&
                encode2D(command_buffer, vertical, render_width, render_height,
                         {{horizontal, 0U}, {accumulation, 0U}, {vertical_weight_buffer, 0U}}, &arguments,
                         sizeof(arguments));
            return encoded;
        };
        if (!enqueue_blur(positive, diffusion, veil_radius, 0.70F) ||
            !enqueue_blur(positive, diffusion, veil_radius * plan.mist().veil_radius_tail, 0.30F) ||
            !enqueue_blur(highlighted, bloom, glow_radius, 0.65F) ||
            !enqueue_blur(highlighted, bloom, glow_radius * plan.mist().glow_radius_tail, 0.35F)) {
            return failed(Error::CommandEncodingFailed);
        }
        const float detail_scale = std::max(0.5F, height_scale / 256.0F);
        if (!enqueue_blur(positive, detail_fine, plan.mist().detail_fine_sigma * detail_scale, 1.0F) ||
            !enqueue_blur(positive, detail_mid, plan.mist().detail_mid_sigma * detail_scale, 1.0F)) {
            return failed(Error::CommandEncodingFailed);
        }
        if (!encode2D(command_buffer, finalize, render_width, render_height,
                      {{source, request.source.byte_offset}, {destination, request.destination.byte_offset},
                       {positive, 0U}, {diffusion, 0U}, {bloom, 0U}, {detail_fine, 0U}, {detail_mid, 0U}},
                      &arguments, sizeof(arguments))) {
            return failed(Error::CommandEncodingFailed);
        }
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }

    }

    if (request.effect == EffectId::OpticalBlur) {
        const int width = request.source.data_window.width;
        const int height = request.source.data_window.height;
        const int render_width = request.render_window.x2 - request.render_window.x1;
        const int render_height = request.render_window.y2 - request.render_window.y1;
        const std::uint32_t half_width = static_cast<std::uint32_t>((width + 1) / 2);
        const std::uint32_t half_height = static_cast<std::uint32_t>((height + 1) / 2);
        const std::uint32_t quarter_width = (half_width + 1U) / 2U;
        const std::uint32_t quarter_height = (half_height + 1U) / 2U;
        const std::uint32_t eighth_width = (quarter_width + 1U) / 2U;
        const std::uint32_t eighth_height = (quarter_height + 1U) / 2U;
        const std::uint32_t half_offset = 0U;
        const std::uint32_t quarter_offset = half_width * half_height;
        const std::uint32_t eighth_offset = quarter_offset + quarter_width * quarter_height;
        OpticalArguments arguments = {
            request.source.data_window.x,
            request.source.data_window.y,
            request.render_window.x1,
            request.render_window.y1,
            width,
            height,
            static_cast<std::uint32_t>(request.source.row_bytes),
            static_cast<std::uint32_t>(request.destination.row_bytes),
            static_cast<std::uint32_t>(plan.workingMode()),
            static_cast<std::uint32_t>(plan.diagnosticView()),
            plan.mixAmount(),
            plan.optical().highlight_response,
            static_cast<std::uint32_t>(request.alpha_association),
            static_cast<std::uint32_t>(plan.optical().sample_count),
            static_cast<std::uint32_t>(render_width),
            static_cast<std::uint32_t>(render_height),
            static_cast<float>(height) * plan.optical().blur / 100.0F,
            plan.optical().anamorphism,
            plan.optical().bokeh_bias,
            plan.optical().cat_eye,
            plan.optical().vignetting,
            plan.optical().coma,
            plan.optical().astigmatism,
            plan.optical().field_curvature,
            plan.optical().chromatic_aberration,
            static_cast<std::uint32_t>(plan.optical().lens_profile),
            half_width,
            half_height,
            quarter_width,
            quarter_height,
            eighth_width,
            eighth_height,
            half_offset,
            quarter_offset,
            eighth_offset,
            0U,
        };
        if (plan.is_identity) {
            id<MTLComputePipelineState> copy = pipelineFor(queue.device, "cbef_optical_copy");
            if (copy == nil) return failed(Error::PipelineCreationFailed);
            if (!encode2D(command_buffer, copy, render_width, render_height,
                          {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                          &arguments, sizeof(arguments))) {
                return failed(Error::CommandEncodingFailed);
            }
            arena_scope.commit(command_buffer);
            [command_buffer commit];
            return RenderSubmission{SubmissionKind::Enqueued, Error::None};
        }
        const std::size_t pixel_count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
        if (pixel_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        const std::size_t sample_length = pixel_count * sizeof(float) * 4U;
        const std::size_t pyramid_count = static_cast<std::size_t>(eighth_offset) +
                                          static_cast<std::size_t>(eighth_width) * eighth_height;
        if (pyramid_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        const std::size_t pyramid_length = pyramid_count * sizeof(float) * 4U;
        ScopedMTLBuffer samples(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLBuffer pyramid(arena_scope.acquire(queue.device, pyramid_length), false);
        if (samples.get() == nil || pyramid.get() == nil) return failed(Error::TemporaryAllocationFailed);
        const auto sequence = detail::makeOpticalSequence(plan.optical().blades, plan.optical().curvature,
                                                          plan.optical().rotation);
        std::array<OpticalPoint, 128> points{};
        for (std::size_t index = 0; index < points.size(); ++index) {
            points[index] = {sequence[index].x, sequence[index].y, sequence[index].weight, 0.0F};
        }
        ScopedMTLBuffer point_buffer(
            arena_scope.acquireBytes(queue.device, points.data(), points.size() * sizeof(OpticalPoint)), false);
        if (point_buffer.get() == nil) return failed(Error::TemporaryAllocationFailed);
        id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_optical_prepare");
        id<MTLComputePipelineState> downsample = pipelineFor(queue.device, "cbef_optical_downsample");
        id<MTLComputePipelineState> render_pipeline = pipelineFor(queue.device, "cbef_optical_render");
        if (prepare == nil || downsample == nil || render_pipeline == nil) {
            return failed(Error::PipelineCreationFailed);
        }
        if (!encode2D(command_buffer, prepare, width, height,
                      {{source, request.source.byte_offset}, {samples, 0U}},
                      &arguments, sizeof(arguments))) {
            return failed(Error::CommandEncodingFailed);
        }
        for (std::uint32_t level = 1U; level <= 3U; ++level) {
            arguments.downsample_level = level;
            const int level_width = static_cast<int>(level == 1U ? half_width :
                                                     level == 2U ? quarter_width : eighth_width);
            const int level_height = static_cast<int>(level == 1U ? half_height :
                                                      level == 2U ? quarter_height : eighth_height);
            if (!encode2D(command_buffer, downsample, level_width, level_height,
                          {{samples, 0U}, {pyramid, 0U}}, &arguments, sizeof(arguments))) {
                return failed(Error::CommandEncodingFailed);
            }
        }
        arguments.downsample_level = 0U;
        if (!encode2D(command_buffer, render_pipeline, render_width, render_height,
                      {{source, request.source.byte_offset}, {destination, request.destination.byte_offset},
                       {samples, 0U}, {pyramid, 0U}, {point_buffer, 0U}},
                      &arguments, sizeof(arguments))) {
            return failed(Error::CommandEncodingFailed);
        }
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }

    if (request.effect == EffectId::LensReflections) {
        const int width = request.source.data_window.width;
        const int height = request.source.data_window.height;
        const int render_width = request.render_window.x2 - request.render_window.x1;
        const int render_height = request.render_window.y2 - request.render_window.y1;
        const std::size_t pixel_count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
        const std::size_t render_count = static_cast<std::size_t>(render_width) * static_cast<std::size_t>(render_height);
        if (pixel_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U) ||
            render_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        if (pixel_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 2U)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        const std::uint32_t tile_columns = static_cast<std::uint32_t>((width + 7) / 8);
        const std::uint32_t tile_rows = static_cast<std::uint32_t>((height + 7) / 8);
        const std::uint32_t half_width = static_cast<std::uint32_t>((width + 1) / 2);
        const std::uint32_t half_height = static_cast<std::uint32_t>((height + 1) / 2);
        const float aspect_ratio = static_cast<float>(std::max(width, height)) /
                                   static_cast<float>(std::max(1, std::min(width, height)));
        const bool has_full_frame_footprint = width >= 1024 && height >= 576 && aspect_ratio <= 4.0F;
        const bool fast_final = has_full_frame_footprint && render_width == width && render_height == height &&
                                plan.diagnosticView() == detail::DiagnosticView::Final;
        const bool direct_source_matte = fast_final && request.external_matte == nullptr &&
                                         std::abs(plan.reflections().source_morphology) < 1.0F &&
                                         plan.reflections().veil <= 0.0F;
        const std::uint32_t projection_downsample = fast_final ? 2U : 1U;
        const std::uint32_t projection_width = static_cast<std::uint32_t>(
            (width + static_cast<int>(projection_downsample) - 1) / static_cast<int>(projection_downsample));
        const std::uint32_t projection_height = static_cast<std::uint32_t>(
            (height + static_cast<int>(projection_downsample) - 1) / static_cast<int>(projection_downsample));
        id<MTLBuffer> matte = source;
        std::uint32_t has_matte = 0U;
        std::uint32_t matte_format = static_cast<std::uint32_t>(PixelFormat::AlphaFloat32);
        std::uint32_t matte_alpha = 0U;
        DataWindow matte_window{0, 0, 1, 1};
        std::uint32_t matte_row_bytes = 4U;
        if (request.external_matte != nullptr) {
            matte = reinterpret_cast<id<MTLBuffer>>(request.external_matte->surface.data);
            if (matte == nil) return failed(Error::BackendUnavailable);
            const FrameSurface& matte_surface = request.external_matte->surface;
            const std::size_t matte_pixel_bytes = matte_surface.pixel_format == PixelFormat::AlphaFloat32
                                                      ? sizeof(float)
                                                      : sizeof(float) * 4U;
            const std::size_t matte_extent = static_cast<std::size_t>(matte_surface.data_window.height - 1) *
                                                 matte_surface.row_bytes +
                                             static_cast<std::size_t>(matte_surface.data_window.width) *
                                                 matte_pixel_bytes;
            if (matte_surface.byte_offset > static_cast<std::size_t>(matte.length) ||
                matte_extent > static_cast<std::size_t>(matte.length) - matte_surface.byte_offset ||
                matte_surface.row_bytes > std::numeric_limits<std::uint32_t>::max()) {
                return failed(Error::InvalidStride);
            }
            has_matte = 1U;
            matte_format = static_cast<std::uint32_t>(matte_surface.pixel_format);
            matte_alpha = static_cast<std::uint32_t>(request.external_matte->alpha_association);
            matte_window = matte_surface.data_window;
            matte_row_bytes = static_cast<std::uint32_t>(matte_surface.row_bytes);
        }
        LensV2Arguments base = {
            request.source.data_window.x,
            request.source.data_window.y,
            request.render_window.x1,
            request.render_window.y1,
            width,
            height,
            static_cast<std::uint32_t>(request.source.row_bytes),
            static_cast<std::uint32_t>(request.destination.row_bytes),
            static_cast<std::uint32_t>(plan.workingMode()),
            static_cast<std::uint32_t>(plan.diagnosticView()),
            plan.mixAmount(),
            plan.reflections().amount,
            plan.reflections().threshold,
            plan.reflections().spread,
            plan.reflections().blur,
            plan.reflections().chroma,
            plan.reflections().anamorphism,
            static_cast<std::uint32_t>(request.alpha_association),
            static_cast<std::uint32_t>(render_width),
            static_cast<std::uint32_t>(render_height),
            plan.reflections().source_mode,
            plan.reflections().source_metric,
            plan.reflections().source_gamma,
            plan.reflections().source_smoothness,
            plan.reflections().source_morphology,
            plan.reflections().manual_x,
            plan.reflections().manual_y,
            plan.reflections().manual_size,
            plan.reflections().manual_intensity,
            plan.reflections().manual_color,
            static_cast<float>(request.source.data_window.x + width / 2) +
                plan.reflections().center_x / 100.0F * 0.5F * static_cast<float>(width),
            static_cast<float>(request.source.data_window.y + height / 2) +
                plan.reflections().center_y / 100.0F * 0.5F * static_cast<float>(height),
            plan.reflections().background_adaptation,
            plan.reflections().veil,
            plan.reflections().element_solo,
            has_matte,
            matte_format,
            matte_alpha,
            matte_window.x,
            matte_window.y,
            matte_window.width,
            matte_window.height,
            matte_row_bytes,
            static_cast<float>(request.render_scale.x),
            static_cast<float>(request.render_scale.y),
            tile_columns,
            tile_rows,
            half_width,
            half_height,
            static_cast<std::uint32_t>(std::clamp(plan.reflections().lens_model, 0, 2)),
            has_full_frame_footprint ? 1U : 0U,
            projection_downsample,
            projection_width,
            projection_height,
        };
        if (plan.is_identity) {
            id<MTLComputePipelineState> copy = pipelineFor(queue.device, "cbef_lens_copy");
            if (copy == nil) return failed(Error::PipelineCreationFailed);
            if (!encode2D(command_buffer, copy, render_width, render_height,
                          {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                          &base, sizeof(base))) {
                return failed(Error::CommandEncodingFailed);
            }
            arena_scope.commit(command_buffer);
            [command_buffer commit];
            return RenderSubmission{SubmissionKind::Enqueued, Error::None};
        }
        const std::size_t matte_length = pixel_count * sizeof(float) * 2U;
        const std::size_t half_count = static_cast<std::size_t>(half_width) * static_cast<std::size_t>(half_height);
        const std::size_t half_length = half_count * sizeof(float) * 4U;
        const std::size_t projection_count = static_cast<std::size_t>(projection_width) *
                                             static_cast<std::size_t>(projection_height);
        const std::size_t projection_length = projection_count * sizeof(float) * 4U;
        const std::size_t tile_count = static_cast<std::size_t>(tile_columns) * static_cast<std::size_t>(tile_rows);
        const std::size_t selection_group_count = (tile_count + 255U) / 256U;
        if (half_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U) ||
            tile_count > std::numeric_limits<std::size_t>::max() / 64U) {
            return failed(Error::TemporaryAllocationFailed);
        }
        ScopedMTLBuffer raw_mattes(arena_scope.acquire(queue.device, matte_length), false);
        ScopedMTLBuffer morphed_mattes(std::abs(plan.reflections().source_morphology) >= 1.0F
                                           ? arena_scope.acquire(queue.device, matte_length)
                                           : nil,
                                       false);
        id<MTLBuffer> final_mattes = morphed_mattes.get() != nil ? morphed_mattes.get() : raw_mattes.get();
        ScopedMTLBuffer half_source(arena_scope.acquire(queue.device, half_length), false);
        ScopedMTLBuffer projected(base.projection_downsample > 1U
                                      ? arena_scope.acquire(queue.device, projection_length)
                                      : nil,
                                  false);
        ScopedMTLBuffer tiles(arena_scope.acquire(queue.device, tile_count * 64U), false);
        ScopedMTLBuffer group_candidates(arena_scope.acquire(queue.device, selection_group_count * 2U * 8U * 32U), false);
        ScopedMTLBuffer candidates(arena_scope.acquire(queue.device, 16U * 32U), false);
        ScopedMTLBuffer denominators(arena_scope.acquire(queue.device, 40U * sizeof(float) * 4U), false);
        std::array<LensElementGpu, 5> elements{};
        for (std::size_t index = 0; index < elements.size(); ++index) {
            const detail::GhostElementPlan& item = plan.reflections().elements[index];
            elements[index] = {item.axis_position,
                               item.magnification,
                               item.defocus,
                               item.aperture_clip,
                               item.ring_profile,
                               item.radial_falloff,
                               item.spectral_tint[0],
                               item.spectral_tint[1],
                               item.spectral_tint[2],
                               item.dispersion,
                               item.energy,
                               item.background_falloff,
                               item.streak_aspect,
                               item.pattern_retention,
                               static_cast<std::uint32_t>(item.shape),
                               0U};
        }
        ScopedMTLBuffer element_buffer(
            arena_scope.acquireBytes(queue.device, elements.data(), elements.size() * sizeof(LensElementGpu)), false);
        id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_lens_prepare_v2");
        id<MTLComputePipelineState> morphology = pipelineFor(queue.device, "cbef_lens_morphology_v2");
        id<MTLComputePipelineState> half = pipelineFor(queue.device, "cbef_lens_half_source_v2");
        id<MTLComputePipelineState> tile = pipelineFor(queue.device, "cbef_lens_tiles_v2");
        id<MTLComputePipelineState> select_groups = pipelineFor(queue.device, "cbef_lens_select_groups_v2");
        id<MTLComputePipelineState> select_finalize = pipelineFor(queue.device, "cbef_lens_select_finalize_v2");
        id<MTLComputePipelineState> denominator = pipelineFor(queue.device, "cbef_lens_denominators_v2");
        id<MTLComputePipelineState> finalize = pipelineFor(queue.device, "cbef_lens_finalize_v2");
        id<MTLComputePipelineState> upscale = pipelineFor(queue.device, "cbef_lens_upscale_v2");
        if (raw_mattes.get() == nil || final_mattes == nil || half_source.get() == nil || tiles.get() == nil ||
            group_candidates.get() == nil || candidates.get() == nil || denominators.get() == nil ||
            element_buffer.get() == nil || (base.projection_downsample > 1U && projected.get() == nil)) {
            return failed(Error::TemporaryAllocationFailed);
        }
        if (prepare == nil || morphology == nil || half == nil || tile == nil || select_groups == nil ||
            select_finalize == nil || denominator == nil || finalize == nil ||
            (base.projection_downsample > 1U && upscale == nil)) {
            return failed(Error::PipelineCreationFailed);
        }
        const NSUInteger matte_offset = request.external_matte != nullptr
                                            ? static_cast<NSUInteger>(request.external_matte->surface.byte_offset)
                                            : request.source.byte_offset;
        if (!direct_source_matte &&
            !encode2D(command_buffer, prepare, width, height,
                      {{source, request.source.byte_offset}, {matte, matte_offset}, {raw_mattes.get(), 0U}},
                      &base, sizeof(base))) {
            return failed(Error::CommandEncodingFailed);
        }
        if (morphed_mattes.get() != nil &&
            !encode2D(command_buffer, morphology, width, height,
                      {{raw_mattes.get(), 0U}, {matte, matte_offset}, {morphed_mattes.get(), 0U}},
                      &base, sizeof(base))) {
            return failed(Error::CommandEncodingFailed);
        }
        LensV2Arguments projection_arguments = base;
        if (base.projection_downsample > 1U) {
            projection_arguments.destination_row_bytes = projection_width * static_cast<std::uint32_t>(sizeof(float) * 4U);
            projection_arguments.render_width = projection_width;
            projection_arguments.render_height = projection_height;
        }
        if (!encode2D(command_buffer, half, static_cast<int>(half_width), static_cast<int>(half_height),
                      {{source, request.source.byte_offset}, {final_mattes, 0U}, {half_source.get(), 0U}},
                      &base, sizeof(base)) ||
            !encode2D(command_buffer, tile, static_cast<int>(tile_columns), static_cast<int>(tile_rows),
                      {{source, request.source.byte_offset}, {final_mattes, 0U}, {tiles.get(), 0U}},
                      &base, sizeof(base)) ||
            !encode2D(command_buffer, select_groups, static_cast<int>(selection_group_count), 2,
                      {{tiles.get(), 0U}, {group_candidates.get(), 0U}}, &base, sizeof(base)) ||
            !encode2D(command_buffer, select_finalize, 1, 1,
                      {{group_candidates.get(), 0U}, {candidates.get(), 0U}}, &base, sizeof(base)) ||
            !encode2D(command_buffer, denominator, 40, 1,
                      {{source, request.source.byte_offset}, {final_mattes, 0U}, {candidates.get(), 0U},
                       {element_buffer.get(), 0U}, {denominators.get(), 0U}},
                      &base, sizeof(base)) ||
            !encode2D(command_buffer, finalize,
                      base.projection_downsample > 1U ? static_cast<int>(projection_width) : render_width,
                      base.projection_downsample > 1U ? static_cast<int>(projection_height) : render_height,
                      {{source, request.source.byte_offset},
                       {base.projection_downsample > 1U ? projected.get() : destination,
                        base.projection_downsample > 1U ? 0U : request.destination.byte_offset},
                       {final_mattes, 0U}, {half_source.get(), 0U}, {candidates.get(), 0U},
                       {element_buffer.get(), 0U}, {denominators.get(), 0U}},
                      &projection_arguments, sizeof(projection_arguments))) {
            return failed(Error::CommandEncodingFailed);
        }
        if (base.projection_downsample > 1U) {
            LensV2Arguments upscale_arguments = base;
            upscale_arguments.destination_row_bytes = static_cast<std::uint32_t>(request.destination.row_bytes);
            if (!encode2D(command_buffer, upscale, width, height,
                          {{source, request.source.byte_offset}, {destination, request.destination.byte_offset},
                           {projected.get(), 0U}},
                          &upscale_arguments, sizeof(upscale_arguments))) {
                return failed(Error::CommandEncodingFailed);
            }
        }
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }

    if (request.effect != EffectId::Halation) return failed(Error::UnsupportedEffectId);

    const int width = request.source.data_window.width;
    const int height = request.source.data_window.height;
    const int render_width = request.render_window.x2 - request.render_window.x1;
    const int render_height = request.render_window.y2 - request.render_window.y1;
    if (plan.is_identity) {
        id<MTLComputePipelineState> copy = pipelineFor(queue.device, "cbef_copy_v2");
        if (copy == nil) return failed(Error::PipelineCreationFailed);
        const CopyArguments identity = {
            request.source.data_window.x, request.source.data_window.y, request.render_window.x1,
            request.render_window.y1, render_width, render_height, static_cast<std::uint32_t>(request.source.row_bytes),
            static_cast<std::uint32_t>(request.destination.row_bytes),
        };
        if (!encode2D(command_buffer, copy, render_width, render_height,
                      {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                      &identity, sizeof(identity))) return failed(Error::CommandEncodingFailed);
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }
    if (plan.diagnosticView() == detail::DiagnosticView::Matte) {
        HalationArguments matte_arguments = {
            request.source.data_window.x, request.source.data_window.y, request.render_window.x1, request.render_window.y1,
            width, height, static_cast<std::uint32_t>(request.source.row_bytes), static_cast<std::uint32_t>(request.destination.row_bytes),
            static_cast<std::uint32_t>(plan.workingMode()), static_cast<std::uint32_t>(plan.diagnosticView()), plan.mixAmount(),
            plan.halation().amount, plan.halation().radius, plan.halation().threshold, plan.halation().warmth, plan.halation().saturation,
            plan.halation().highlights_only ? 1U : 0U, static_cast<std::uint32_t>(request.alpha_association),
            static_cast<std::uint32_t>(render_width), static_cast<std::uint32_t>(render_height), 0U, 0U, 0.0F,
            plan.halation().source_smoothness, plan.halation().global_diffusion, plan.halation().red_bias,
            plan.halation().blue_compensation, plan.halation().core_protection, plan.halation().background_adaptation, 0U,
            plan.halation().color_target_r, plan.halation().color_target_g, plan.halation().color_target_b,
            plan.halation().color_emphasis_mix, static_cast<std::uint32_t>(plan.halation().color_mode)};
        id<MTLComputePipelineState> matte = pipelineFor(queue.device, "cbef_halation_matte");
        if (matte == nil || !encode2D(command_buffer, matte, render_width, render_height,
                                      {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                                      &matte_arguments, sizeof(matte_arguments))) {
            return failed(Error::CommandEncodingFailed);
        }
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }
    const std::size_t pixel_count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
    if (pixel_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U) ||
        static_cast<std::size_t>(render_width) > std::numeric_limits<std::size_t>::max() /
                                                   static_cast<std::size_t>(render_height)) {
        return failed(Error::TemporaryAllocationFailed);
    }
    const bool use_pyramid = width >= 1024 && height >= 576 && render_width > 0 && render_height > 0;
    if (use_pyramid) {
        const std::size_t max_level_width = (static_cast<std::size_t>(width) + 1U) / 2U;
        const std::size_t max_level_height = (static_cast<std::size_t>(height) + 1U) / 2U;
        const std::size_t rg32_row_bytes = alignTextureRowBytes(max_level_width * sizeof(float) * 2U,
                                                                [queue.device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatRG32Float]);
        if (rg32_row_bytes == 0U || max_level_height > std::numeric_limits<std::size_t>::max() / rg32_row_bytes) {
            return failed(Error::TemporaryAllocationFailed);
        }
        const std::size_t source_plane_length = rg32_row_bytes * max_level_height;
        const std::size_t level_length = source_plane_length * 3U;
        id<MTLBuffer> level_samples = arena_scope.acquire(queue.device, level_length);
        id<MTLBuffer> level_horizontal = arena_scope.acquire(queue.device, level_length);
        std::array<id<MTLBuffer>, 3> scatter_outputs{};
        std::array<std::size_t, 3> output_plane_lengths{};
        std::array<std::size_t, 3> output_row_bytes{};
        constexpr std::array<std::uint32_t, 3> downsample = {2U, 4U, 8U};
        for (std::size_t scale = 0U; scale < 3U; ++scale) {
            const std::size_t level_width = (static_cast<std::size_t>(width) + downsample[scale] - 1U) / downsample[scale];
            const std::size_t level_height = (static_cast<std::size_t>(height) + downsample[scale] - 1U) / downsample[scale];
            output_row_bytes[scale] = alignTextureRowBytes(level_width * sizeof(float) * 2U,
                                                            [queue.device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatRG32Float]);
            if (output_row_bytes[scale] == 0U || level_height > std::numeric_limits<std::size_t>::max() / output_row_bytes[scale]) {
                return failed(Error::TemporaryAllocationFailed);
            }
            output_plane_lengths[scale] = output_row_bytes[scale] * level_height;
            if (output_plane_lengths[scale] > std::numeric_limits<std::size_t>::max() / 3U) {
                return failed(Error::TemporaryAllocationFailed);
            }
            scatter_outputs[scale] = arena_scope.acquire(queue.device, output_plane_lengths[scale] * 3U);
        }
        id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_halation_pyramid_prepare_rg32");
        id<MTLComputePipelineState> horizontal = pipelineFor(queue.device, "cbef_halation_pyramid_horizontal_rg32");
        id<MTLComputePipelineState> vertical = pipelineFor(queue.device, "cbef_halation_pyramid_vertical_rg32");
        id<MTLComputePipelineState> composite = pipelineFor(queue.device, "cbef_halation_pyramid_composite");
        if (level_samples == nil || level_horizontal == nil || prepare == nil || horizontal == nil || vertical == nil || composite == nil ||
            scatter_outputs[0] == nil || scatter_outputs[1] == nil || scatter_outputs[2] == nil) {
            return failed(Error::TemporaryAllocationFailed);
        }
        std::array<id<MTLTexture>, 9> level_sample_textures{};
        std::array<id<MTLTexture>, 9> level_horizontal_textures{};
        std::array<id<MTLTexture>, 9> scatter_textures{};
        const auto release_textures = [&]() {
            for (id<MTLTexture>& texture : level_sample_textures) { [texture release]; texture = nil; }
            for (id<MTLTexture>& texture : level_horizontal_textures) { [texture release]; texture = nil; }
            for (id<MTLTexture>& texture : scatter_textures) { [texture release]; texture = nil; }
        };
        for (std::size_t scale = 0U; scale < 3U; ++scale) {
            const int level_width = static_cast<int>((static_cast<std::size_t>(width) + downsample[scale] - 1U) / downsample[scale]);
            const int level_height = static_cast<int>((static_cast<std::size_t>(height) + downsample[scale] - 1U) / downsample[scale]);
            for (std::size_t channel = 0U; channel < 3U; ++channel) {
                const std::size_t plane_offset = channel * source_plane_length;
                level_sample_textures[scale * 3U + channel] = alignedRG32TextureForBuffer(
                    queue.device, level_samples, level_width, level_height, rg32_row_bytes, plane_offset);
                level_horizontal_textures[scale * 3U + channel] = alignedRG32TextureForBuffer(
                    queue.device, level_horizontal, level_width, level_height, rg32_row_bytes, plane_offset);
            }
            for (std::size_t channel = 0U; channel < 3U; ++channel) {
                scatter_textures[scale * 3U + channel] = alignedRG32TextureForBuffer(
                    queue.device, scatter_outputs[scale], level_width, level_height, output_row_bytes[scale],
                    channel * output_plane_lengths[scale]);
            }
            if (level_sample_textures[scale * 3U] == nil || level_sample_textures[scale * 3U + 1U] == nil ||
                level_sample_textures[scale * 3U + 2U] == nil || level_horizontal_textures[scale * 3U] == nil ||
                level_horizontal_textures[scale * 3U + 1U] == nil || level_horizontal_textures[scale * 3U + 2U] == nil ||
                scatter_textures[scale * 3U] == nil || scatter_textures[scale * 3U + 1U] == nil ||
                scatter_textures[scale * 3U + 2U] == nil) {
                release_textures();
                return failed(Error::TemporaryAllocationFailed);
            }
        }
        HalationArguments common = {
            request.source.data_window.x, request.source.data_window.y, request.render_window.x1, request.render_window.y1,
            width, height, static_cast<std::uint32_t>(request.source.row_bytes), static_cast<std::uint32_t>(request.destination.row_bytes),
            static_cast<std::uint32_t>(plan.workingMode()), static_cast<std::uint32_t>(plan.diagnosticView()), plan.mixAmount(),
            plan.halation().amount, plan.halation().radius, plan.halation().threshold, plan.halation().warmth,
            plan.halation().saturation, plan.halation().highlights_only ? 1U : 0U, static_cast<std::uint32_t>(request.alpha_association),
            static_cast<std::uint32_t>(render_width), static_cast<std::uint32_t>(render_height), 0U, 0U, 0.0F,
            plan.halation().source_smoothness, plan.halation().global_diffusion, plan.halation().red_bias,
            plan.halation().blue_compensation, plan.halation().core_protection, plan.halation().background_adaptation, 0U,
            plan.halation().color_target_r, plan.halation().color_target_g, plan.halation().color_target_b,
            plan.halation().color_emphasis_mix, static_cast<std::uint32_t>(plan.halation().color_mode)};
        bool initialized = false;
        const auto encode_pyramid_branch = [&](float base_sigma, const std::array<float, 3>& factors,
                                               const std::array<float, 3>& weights, bool global_branch) -> bool {
            if (base_sigma <= 1.0e-6F) return true;
            (void)weights;
            constexpr std::array<float, 3> channel_factors = {1.20F, 1.00F, 0.82F};
            for (std::size_t scale = 0U; scale < 3U; ++scale) {
                const std::uint32_t factor = downsample[scale];
                const std::uint32_t level_width = static_cast<std::uint32_t>((static_cast<std::size_t>(width) + factor - 1U) / factor);
                const std::uint32_t level_height = static_cast<std::uint32_t>((static_cast<std::size_t>(height) + factor - 1U) / factor);
                HalationPyramidRG32Arguments args{};
                args.base = common;
                args.level_width = level_width;
                args.level_height = level_height;
                args.downsample = factor;
                args.source_row_stride = static_cast<std::uint32_t>(rg32_row_bytes / (sizeof(float) * 2U));
                args.output_row_stride = static_cast<std::uint32_t>(output_row_bytes[scale] / (sizeof(float) * 2U));
                args.source_plane_stride = static_cast<std::uint32_t>(source_plane_length / (sizeof(float) * 2U));
                args.output_plane_stride = static_cast<std::uint32_t>(output_plane_lengths[scale] / (sizeof(float) * 2U));
                std::vector<GaussianPair> horizontal_pairs;
                std::vector<GaussianPair> vertical_pairs;
                for (std::size_t channel = 0U; channel < 3U; ++channel) {
                    const float sigma_y = base_sigma * factors[scale] * channel_factors[channel] / static_cast<float>(factor);
                    const float sigma_x = sigma_y * static_cast<float>(request.render_scale.y / request.render_scale.x);
                    const std::vector<GaussianPair> channel_horizontal = gaussianLinearPairs(gaussianKernel(sigma_x));
                    const std::vector<GaussianPair> channel_vertical = gaussianLinearPairs(gaussianKernel(sigma_y));
                    args.horizontal_pair_offsets[channel] = static_cast<std::uint32_t>(horizontal_pairs.size());
                    args.vertical_pair_offsets[channel] = static_cast<std::uint32_t>(vertical_pairs.size());
                    args.horizontal_radii[channel] = static_cast<std::uint32_t>(channel_horizontal.size() > 1U ?
                                                                                  (channel_horizontal.size() - 1U) * 2U : 0U);
                    args.vertical_radii[channel] = static_cast<std::uint32_t>(channel_vertical.size() > 1U ?
                                                                                (channel_vertical.size() - 1U) * 2U : 0U);
                    horizontal_pairs.insert(horizontal_pairs.end(), channel_horizontal.begin(), channel_horizontal.end());
                    vertical_pairs.insert(vertical_pairs.end(), channel_vertical.begin(), channel_vertical.end());
                }
                ScopedMTLBuffer horizontal_pair_buffer(
                    arena_scope.acquireBytes(queue.device, horizontal_pairs.data(), horizontal_pairs.size() * sizeof(GaussianPair)), false);
                ScopedMTLBuffer vertical_pair_buffer(
                    arena_scope.acquireBytes(queue.device, vertical_pairs.data(), vertical_pairs.size() * sizeof(GaussianPair)), false);
                if (horizontal_pair_buffer.get() == nil || vertical_pair_buffer.get() == nil ||
                    !encode2D(command_buffer, prepare, static_cast<int>(level_width), static_cast<int>(level_height),
                              {{source, request.source.byte_offset}, {level_samples, 0U}}, &args, sizeof(args)) ||
                    !encode2DTextured(command_buffer, horizontal, static_cast<int>(level_width), static_cast<int>(level_height),
                                      {level_sample_textures[scale * 3U], level_sample_textures[scale * 3U + 1U],
                                       level_sample_textures[scale * 3U + 2U]},
                                      {{level_horizontal, 0U}, {horizontal_pair_buffer, 0U}}, &args, sizeof(args)) ||
                    !encode2DTextured(command_buffer, vertical, static_cast<int>(level_width), static_cast<int>(level_height),
                                      {level_horizontal_textures[scale * 3U], level_horizontal_textures[scale * 3U + 1U],
                                       level_horizontal_textures[scale * 3U + 2U]},
                                      {{scatter_outputs[scale], 0U}, {vertical_pair_buffer, 0U}}, &args, sizeof(args))) return false;
            }
            HalationPyramidCompositeArguments composite_args{};
            composite_args.base = common;
            composite_args.downsample[0] = downsample[0];
            composite_args.downsample[1] = downsample[1];
            composite_args.downsample[2] = downsample[2];
            composite_args.global_branch = global_branch ? 1U : 0U;
            composite_args.initialize = global_branch && initialized ? 0U : 1U;
            if (!encode2DTextured(command_buffer, composite, render_width, render_height,
                                  {scatter_textures[0], scatter_textures[1], scatter_textures[2], scatter_textures[3],
                                   scatter_textures[4], scatter_textures[5], scatter_textures[6], scatter_textures[7], scatter_textures[8]},
                                  {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}},
                                  &composite_args, sizeof(composite_args))) return false;
            if (!global_branch || common.diagnostic_view != 5U) initialized = true;
            return true;
        };
        if (!encode_pyramid_branch(static_cast<float>(height) * (plan.halation().radius / 100.0F),
                                   {0.35F, 0.75F, 1.5F}, {0.50F, 0.35F, 0.15F}, false) ||
            !encode_pyramid_branch(static_cast<float>(height) * (std::clamp(plan.halation().global_diffusion, 0.0F, 100.0F) / 100.0F) * 0.35F,
                                   {0.60F, 1.30F, 2.40F}, {0.52F, 0.32F, 0.16F}, true)) {
            release_textures();
            return failed(Error::CommandEncodingFailed);
        }
        release_textures();
        if (!initialized) return failed(Error::CommandEncodingFailed);
        arena_scope.commit(command_buffer);
        [command_buffer commit];
        return RenderSubmission{SubmissionKind::Enqueued, Error::None};
    }
    const std::size_t sample_length = pixel_count * sizeof(float) * 4U;
    const std::size_t halo_count = static_cast<std::size_t>(render_width) * static_cast<std::size_t>(render_height);
    if (halo_count > std::numeric_limits<std::size_t>::max() / (sizeof(float) * 4U)) {
        return failed(Error::TemporaryAllocationFailed);
    }
    // Aligned fused path: prepare, one multi-scale horizontal pass, and one vertical/final pass.
    if (render_width > 0 && render_height > 0 && plan.halation().global_diffusion <= 0.0F) {
        ScopedMTLBuffer fused_samples(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLBuffer fused_scratch0(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLBuffer fused_scratch1(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLBuffer fused_scratch2(arena_scope.acquire(queue.device, sample_length), false);
        ScopedMTLTexture samples_texture(linearTextureForBuffer(queue.device, fused_samples, width, height));
        ScopedMTLTexture scratch0_texture(linearTextureForBuffer(queue.device, fused_scratch0, width, height));
        ScopedMTLTexture scratch1_texture(linearTextureForBuffer(queue.device, fused_scratch1, width, height));
        ScopedMTLTexture scratch2_texture(linearTextureForBuffer(queue.device, fused_scratch2, width, height));
        if (fused_samples.get() != nil && fused_scratch0.get() != nil && fused_scratch1.get() != nil && fused_scratch2.get() != nil &&
            samples_texture.get() != nil && scratch0_texture.get() != nil && scratch1_texture.get() != nil && scratch2_texture.get() != nil) {
            HalationFusedArguments fused{};
            fused.base = {request.source.data_window.x, request.source.data_window.y, request.render_window.x1,
                          request.render_window.y1, width, height, static_cast<std::uint32_t>(request.source.row_bytes),
                          static_cast<std::uint32_t>(request.destination.row_bytes), static_cast<std::uint32_t>(plan.workingMode()),
                          static_cast<std::uint32_t>(plan.diagnosticView()), plan.mixAmount(), plan.halation().amount, plan.halation().radius,
                          plan.halation().threshold, plan.halation().warmth, plan.halation().saturation,
                          plan.halation().highlights_only ? 1U : 0U, static_cast<std::uint32_t>(request.alpha_association),
                          static_cast<std::uint32_t>(render_width), static_cast<std::uint32_t>(render_height), 0U, 0U, 0.0F,
                          plan.halation().source_smoothness, plan.halation().global_diffusion,
                          plan.halation().red_bias, plan.halation().blue_compensation,
                          plan.halation().core_protection, plan.halation().background_adaptation, 0U,
                          plan.halation().color_target_r, plan.halation().color_target_g,
                          plan.halation().color_target_b, plan.halation().color_emphasis_mix,
                          static_cast<std::uint32_t>(plan.halation().color_mode)};
            std::vector<GaussianPair> horizontal_pairs;
            std::vector<GaussianPair> vertical_pairs;
            try {
                const std::array<float, 3> factors = {0.35F, 0.75F, 1.5F};
                const std::array<float, 3> weights = {0.50F, 0.35F, 0.15F};
                for (std::size_t scale = 0; scale < 3U; ++scale) {
                    const float sigma_y = static_cast<float>(height) * (plan.halation().radius / 100.0F) * factors[scale];
                    const float sigma_x = sigma_y * static_cast<float>(request.render_scale.y / request.render_scale.x);
                    const std::vector<GaussianPair> h = gaussianLinearPairs(gaussianKernel(sigma_x));
                    const std::vector<GaussianPair> v = gaussianLinearPairs(gaussianKernel(sigma_y));
                    fused.pair_offsets[scale] = static_cast<std::uint32_t>(horizontal_pairs.size());
                    fused.pair_counts[scale] = static_cast<std::uint32_t>(h.size() - 1U);
                    fused.vertical_pair_offsets[scale] = static_cast<std::uint32_t>(vertical_pairs.size());
                    fused.vertical_pair_counts[scale] = static_cast<std::uint32_t>(v.size() - 1U);
                    fused.scale_weights[scale] = weights[scale];
                    horizontal_pairs.insert(horizontal_pairs.end(), h.begin(), h.end());
                    vertical_pairs.insert(vertical_pairs.end(), v.begin(), v.end());
                }
            } catch (const std::bad_alloc&) {
                horizontal_pairs.clear();
                vertical_pairs.clear();
            }
            ScopedMTLBuffer horizontal_pair_buffer(
                arena_scope.acquireBytes(queue.device, horizontal_pairs.data(), horizontal_pairs.size() * sizeof(GaussianPair)), false);
            ScopedMTLBuffer vertical_pair_buffer(
                arena_scope.acquireBytes(queue.device, vertical_pairs.data(), vertical_pairs.size() * sizeof(GaussianPair)), false);
            id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_halation_prepare");
            id<MTLComputePipelineState> horizontal = pipelineFor(queue.device, "cbef_halation_horizontal_multi_buffer");
            id<MTLComputePipelineState> final = pipelineFor(queue.device, "cbef_halation_vertical_final_buffer");
            if (!horizontal_pairs.empty() && !vertical_pairs.empty() && horizontal_pair_buffer.get() != nil && vertical_pair_buffer.get() != nil &&
                prepare != nil && horizontal != nil && final != nil &&
                encode2D(command_buffer, prepare, width, height, {{source, request.source.byte_offset}, {fused_samples, 0U}},
                         &fused.base, sizeof(fused.base)) &&
                encode2DTextured(command_buffer, horizontal, width, height,
                                 {samples_texture.get(), scratch0_texture.get(), scratch1_texture.get(), scratch2_texture.get()},
                                 {{horizontal_pair_buffer, 0U}}, &fused, sizeof(fused)) &&
                encode2DTextured(command_buffer, final, render_width, render_height,
                                 {scratch0_texture.get(), scratch1_texture.get(), scratch2_texture.get(), samples_texture.get()},
                                 {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}, {vertical_pair_buffer, 0U}},
                                 &fused, sizeof(fused))) {
                arena_scope.commit(command_buffer);
                [command_buffer commit];
                return RenderSubmission{SubmissionKind::Enqueued, Error::None};
            }
        }
    }
    ScopedMTLBuffer samples(arena_scope.acquire(queue.device, sample_length), false);
    ScopedMTLBuffer horizontal(arena_scope.acquire(queue.device, sample_length), false);
    ScopedMTLBuffer halo(arena_scope.acquire(queue.device, halo_count * sizeof(float) * 4U), false);
    ScopedMTLBuffer global_halo(arena_scope.acquire(queue.device, halo_count * sizeof(float) * 4U), false);
    if (samples.get() == nil || horizontal.get() == nil || halo.get() == nil || global_halo.get() == nil) {
        return failed(Error::TemporaryAllocationFailed);
    }
    ScopedMTLTexture samples_texture(linearTextureForBuffer(queue.device, samples, width, height));
    ScopedMTLTexture horizontal_texture(linearTextureForBuffer(queue.device, horizontal, width, height));
    // The linear-pair path is an approximation of the CPU reference. Keep the
    // exact weight-buffer path for Halation parity; wide frames use the pyramid
    // adapter above instead of this full-resolution fallback.
    bool fast_path = false;

    const HalationArguments base = {
        request.source.data_window.x, request.source.data_window.y, request.render_window.x1, request.render_window.y1,
        width, height, static_cast<std::uint32_t>(request.source.row_bytes),
        static_cast<std::uint32_t>(request.destination.row_bytes), static_cast<std::uint32_t>(plan.workingMode()),
        static_cast<std::uint32_t>(plan.diagnosticView()), plan.mixAmount(), plan.halation().amount, plan.halation().radius,
        plan.halation().threshold, plan.halation().warmth, plan.halation().saturation,
        plan.halation().highlights_only ? 1U : 0U, static_cast<std::uint32_t>(request.alpha_association),
        static_cast<std::uint32_t>(render_width), static_cast<std::uint32_t>(render_height), 0U, 0U, 0.0F,
        plan.halation().source_smoothness, plan.halation().global_diffusion,
        plan.halation().red_bias, plan.halation().blue_compensation,
        plan.halation().core_protection, plan.halation().background_adaptation,
        0U, plan.halation().color_target_r, plan.halation().color_target_g,
        plan.halation().color_target_b, plan.halation().color_emphasis_mix,
        static_cast<std::uint32_t>(plan.halation().color_mode),
    };
    HalationArguments arguments = base;
    id<MTLComputePipelineState> prepare = pipelineFor(queue.device, "cbef_halation_prepare");
    id<MTLComputePipelineState> horizontal_pipeline = pipelineFor(queue.device, "cbef_halation_horizontal");
    id<MTLComputePipelineState> vertical = pipelineFor(queue.device, "cbef_halation_vertical");
    id<MTLComputePipelineState> finalize = pipelineFor(queue.device, "cbef_halation_finalize");
    id<MTLComputePipelineState> horizontal_linear = fast_path ? pipelineFor(queue.device, "cbef_halation_horizontal_linear") : nil;
    id<MTLComputePipelineState> vertical_linear = fast_path ? pipelineFor(queue.device, "cbef_halation_vertical_linear") : nil;
    if (fast_path && (horizontal_linear == nil || vertical_linear == nil)) fast_path = false;
    if (prepare == nil || horizontal_pipeline == nil || vertical == nil || finalize == nil) {
        return failed(Error::PipelineCreationFailed);
    }
    std::memset(halo.get().contents, 0, halo_count * sizeof(float) * 4U);
    std::memset(global_halo.get().contents, 0, halo_count * sizeof(float) * 4U);
    if (!encode2D(command_buffer, prepare, width, height, {{source, request.source.byte_offset}, {samples, 0U}},
                  &arguments, sizeof(arguments))) {
        return failed(Error::CommandEncodingFailed);
    }
    const auto encode_scatter = [&](float base_sigma, const std::array<float, 3>& factors,
                                    const std::array<float, 3>& weights, id<MTLBuffer> target) -> bool {
        constexpr std::array<float, 3> channel_factors = {1.20F, 1.00F, 0.82F};
        for (std::size_t scale = 0; scale < 3U; ++scale) {
            for (std::size_t channel = 0; channel < 3U; ++channel) {
                const float sigma_y = base_sigma * factors[scale] * channel_factors[channel];
                const float sigma_x = sigma_y * static_cast<float>(request.render_scale.y / request.render_scale.x);
                const std::vector<float> horizontal_weights = gaussianKernel(sigma_x);
                const std::vector<float> vertical_weights = gaussianKernel(sigma_y);
                ScopedMTLBuffer horizontal_weight_buffer(
                    arena_scope.acquireBytes(queue.device, horizontal_weights.data(), horizontal_weights.size() * sizeof(float)), false);
                ScopedMTLBuffer vertical_weight_buffer(
                    arena_scope.acquireBytes(queue.device, vertical_weights.data(), vertical_weights.size() * sizeof(float)), false);
                if (horizontal_weight_buffer.get() == nil || vertical_weight_buffer.get() == nil) return false;
                arguments.horizontal_radius = static_cast<std::uint32_t>(horizontal_weights.size() / 2U);
                arguments.vertical_radius = static_cast<std::uint32_t>(vertical_weights.size() / 2U);
                arguments.scale_weight = weights[scale];
                arguments.channel = static_cast<std::uint32_t>(channel);
                if (fast_path) {
                    const std::vector<GaussianPair> horizontal_pairs = gaussianLinearPairs(horizontal_weights);
                    const std::vector<GaussianPair> vertical_pairs = gaussianLinearPairs(vertical_weights);
                    ScopedMTLBuffer horizontal_pair_buffer(
                        arena_scope.acquireBytes(queue.device, horizontal_pairs.data(), horizontal_pairs.size() * sizeof(GaussianPair)), false);
                    ScopedMTLBuffer vertical_pair_buffer(
                        arena_scope.acquireBytes(queue.device, vertical_pairs.data(), vertical_pairs.size() * sizeof(GaussianPair)), false);
                    if (horizontal_pair_buffer.get() == nil || vertical_pair_buffer.get() == nil) return false;
                    if (!encode2DTextured(command_buffer, horizontal_linear, width, height, {samples_texture.get()},
                                          {{horizontal, 0U}, {horizontal_pair_buffer, 0U}}, &arguments, sizeof(arguments)) ||
                        !encode2DTextured(command_buffer, vertical_linear, render_width, render_height,
                                          {horizontal_texture.get()},
                                          {{target, 0U}, {samples, 0U}, {vertical_pair_buffer, 0U}}, &arguments,
                                          sizeof(arguments))) return false;
                } else if (!encode2D(command_buffer, horizontal_pipeline, width, height,
                                     {{samples, 0U}, {horizontal, 0U}, {horizontal_weight_buffer, 0U}}, &arguments,
                                     sizeof(arguments)) ||
                           !encode2D(command_buffer, vertical, render_width, render_height,
                                     {{horizontal, 0U}, {target, 0U}, {samples, 0U}, {vertical_weight_buffer, 0U}}, &arguments,
                                     sizeof(arguments))) return false;
            }
        }
        return true;
    };
    if (!encode_scatter(static_cast<float>(height) * (plan.halation().radius / 100.0F),
                        {0.35F, 0.75F, 1.5F}, {0.50F, 0.35F, 0.15F}, halo) ||
        !encode_scatter(static_cast<float>(height) * (std::clamp(plan.halation().global_diffusion, 0.0F, 100.0F) / 100.0F) * 0.35F,
                        {0.60F, 1.30F, 2.40F}, {0.52F, 0.32F, 0.16F}, global_halo)) {
        return failed(Error::TemporaryAllocationFailed);
    }
    if (!encode2D(command_buffer, finalize, render_width, render_height,
                  {{source, request.source.byte_offset}, {destination, request.destination.byte_offset}, {halo, 0U},
                   {global_halo, 0U}},
                  &arguments, sizeof(arguments))) {
        return failed(Error::CommandEncodingFailed);
    }
    arena_scope.commit(command_buffer);
    [command_buffer commit];
    return RenderSubmission{SubmissionKind::Enqueued, Error::None};
}

}
