#include "audio_devices.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <wrl/client.h>

#include <memory>
#include <string>

namespace {

using Microsoft::WRL::ComPtr;
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Undocumented but widely used COM interface for setting the default audio
// endpoint. Kept local to this translation unit.
MIDL_INTERFACE("f8679f50-850a-41cf-9c72-430f290290c8")
IPolicyConfig : public IUnknown {
  virtual HRESULT STDMETHODCALLTYPE GetMixFormat(LPCWSTR, void**) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetDeviceFormat(LPCWSTR, INT, void**) = 0;
  virtual HRESULT STDMETHODCALLTYPE ResetDeviceFormat(LPCWSTR) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetDeviceFormat(LPCWSTR, void*, void*) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetEndpointProperty(LPCWSTR, void*, void*) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetEndpointProperty(LPCWSTR, void*, void*, void*) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetDeviceProperty(LPCWSTR, void*, void*) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetDefaultEndpoint(LPCWSTR, int) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetEndpointVisibility(LPCWSTR, INT) = 0;
};

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0,
                                   nullptr, nullptr);
  std::string out(size > 0 ? size - 1 : 0, '\0');
  if (size > 0) {
    ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, &out[0], size, nullptr,
                          nullptr);
  }
  return out;
}

std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) return {};
  int size = ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  std::wstring out(size > 0 ? size - 1 : 0, L'\0');
  if (size > 0) {
    ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, &out[0], size);
  }
  return out;
}

EncodableList ListDevices() {
  EncodableList devices;
  ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                  CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) return devices;

  ComPtr<IMMDeviceCollection> collection;
  hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
  if (FAILED(hr)) return devices;

  UINT count = 0;
  collection->GetCount(&count);
  for (UINT i = 0; i < count; ++i) {
    ComPtr<IMMDevice> device;
    if (FAILED(collection->Item(i, &device))) continue;

    LPWSTR idRaw = nullptr;
    if (FAILED(device->GetId(&idRaw)) || idRaw == nullptr) continue;
    std::wstring idWide(idRaw);
    ::CoTaskMemFree(idRaw);

    std::wstring name = idWide;
    ComPtr<IPropertyStore> props;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &props))) {
      PROPVARIANT value;
      ::PropVariantInit(&value);
      if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &value)) &&
          value.pwszVal != nullptr) {
        name = value.pwszVal;
      }
      ::PropVariantClear(&value);
    }

    EncodableMap map;
    map[EncodableValue("id")] = EncodableValue(WideToUtf8(idWide));
    map[EncodableValue("name")] = EncodableValue(WideToUtf8(name));
    devices.push_back(EncodableValue(map));
  }
  return devices;
}

bool SelectDevice(const std::string& id) {
  ComPtr<IPolicyConfig> policy;
  // CLSID_PolicyConfigClient (IPolicyConfig IID is declared by MIDL_INTERFACE).
  const CLSID policyConfigClient = {
      0x87ce5498, 0x68d6, 0x44e5, {0x92, 0x15, 0x6d, 0xa4, 0x7e, 0xf8, 0x83, 0xd8}};
  HRESULT hr = ::CoCreateInstance(policyConfigClient, nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&policy));
  if (FAILED(hr)) return false;
  // eRender = 0, eMultimedia = 1.
  return SUCCEEDED(policy->SetDefaultEndpoint(Utf8ToWide(id).c_str(), 1));
}

}  // namespace

void RegisterAudioDeviceChannel(flutter::BinaryMessenger* messenger) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "com.echo/audio_devices",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "list") {
          result->Success(ListDevices());
        } else if (call.method_name() == "select") {
          const auto* args = std::get_if<EncodableMap>(call.arguments());
          std::string id;
          if (args != nullptr) {
            auto it = args->find(EncodableValue("id"));
            if (it != args->end()) {
              if (const auto* s = std::get_if<std::string>(&it->second)) {
                id = *s;
              }
            }
          }
          result->Success(EncodableValue(SelectDevice(id)));
        } else {
          result->NotImplemented();
        }
      });

  // Intentionally leaked: the channel must outlive the engine. The process is
  // short-lived and this is the standard pattern for one-shot registrations.
  channel.release();
}
