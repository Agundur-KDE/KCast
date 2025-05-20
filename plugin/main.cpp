#include <avahi-client/client.h>
#include <avahi-client/lookup.h>
#include <avahi-common/error.h>
#include <avahi-common/malloc.h>
#include <avahi-common/simple-watch.h>
#include <iostream>

static AvahiSimplePoll* simple_poll = nullptr;

void resolve_callback(
    AvahiServiceResolver* r,
    AvahiIfIndex interface,
    AvahiProtocol protocol,
    AvahiResolverEvent event,
    const char* name,
    const char* type,
    const char* domain,
    const char* host_name,
    const AvahiAddress* address,
    uint16_t port,
    AvahiStringList* txt,
    AvahiLookupResultFlags flags,
    void* userdata)
{

    if (event == AVAHI_RESOLVER_FOUND) {
        char addr_str[AVAHI_ADDRESS_STR_MAX];
        avahi_address_snprint(addr_str, sizeof(addr_str), address);

        std::cout << "🎯 Chromecast gefunden: " << name
                  << "\n  Host: " << host_name
                  << "\n  Adresse: " << addr_str
                  << "\n  Port: " << port << "\n"
                  << std::endl;
    }

    avahi_service_resolver_free(r);
}

void browse_callback(
    AvahiServiceBrowser* b,
    AvahiIfIndex interface,
    AvahiProtocol protocol,
    AvahiBrowserEvent event,
    const char* name,
    const char* type,
    const char* domain,
    AvahiLookupResultFlags flags,
    void* userdata)
{

    AvahiClient* client = static_cast<AvahiClient*>(userdata);

    if (event == AVAHI_BROWSER_NEW) {
        avahi_service_resolver_new(client, interface, protocol,
            name, type, domain,
            AVAHI_PROTO_UNSPEC, static_cast<AvahiLookupFlags>(0),
            resolve_callback, nullptr);
    }
}

void client_callback(AvahiClient* c, AvahiClientState state, void* userdata)
{
    if (state == AVAHI_CLIENT_FAILURE) {
        std::cerr << "Avahi-Client Fehler: " << avahi_strerror(avahi_client_errno(c)) << std::endl;
        avahi_simple_poll_quit(simple_poll);
    }
}

int main()
{
    int error;

    simple_poll = avahi_simple_poll_new();
    if (!simple_poll) {
        std::cerr << "Fehler beim Erstellen des Avahi-Poll-Objekts" << std::endl;
        return 1;
    }

    AvahiClient* client = avahi_client_new(
        avahi_simple_poll_get(simple_poll),
        AVAHI_CLIENT_NO_FAIL,
        client_callback,
        nullptr,
        &error);

    if (!client) {
        std::cerr << "Fehler beim Erstellen des Avahi-Clients: " << avahi_strerror(error) << std::endl;
        return 1;
    }

    AvahiServiceBrowser* browser = avahi_service_browser_new(
        client,
        AVAHI_IF_UNSPEC,
        AVAHI_PROTO_UNSPEC,
        "_googlecast._tcp", "local",
        static_cast<AvahiLookupFlags>(0),
        browse_callback,
        client);

    if (!browser) {
        std::cerr << "Fehler beim Starten des Service-Browsers" << std::endl;
        return 1;
    }

    std::cout << "📡 Suche nach Chromecast-Geräten...\n";
    avahi_simple_poll_loop(simple_poll);

    avahi_service_browser_free(browser);
    avahi_client_free(client);
    avahi_simple_poll_free(simple_poll);

    return 0;
}
