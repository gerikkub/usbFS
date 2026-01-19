
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <cstdlib>

#include <gtest/gtest.h>

std::tuple<uint8_t*,std::size_t> bin_from_asm(const std::string_view& s, const uint32_t addr, const std::string_view& tmp_name);

template <typename T>
class ModTest : public ::testing::Test {

    public:

    virtual void SetUp() override {
        vctx = std::make_unique<VerilatedContext>();
        vcd = std::make_unique<VerilatedVcdC>();
        mod = std::make_unique<T>(vctx.get());
        timeui = 0;
        clk_cnt = 0;

        if (const char* env_dump_vcd = std::getenv("DUMP_VCD")) {
            int en_vcd = std::atoi(env_dump_vcd);
            if (en_vcd > 0) {
                vctx->traceEverOn(true);
                mod->trace(vcd.get(), 99);
                auto ut = ::testing::UnitTest::GetInstance();
                auto test = ut->current_test_info();
                std::stringstream trace_name;
                trace_name << "test_" <<
                              test->test_suite_name() << "_" <<
                              test->name() << ".vcd";

                vcd->open(trace_name.str().c_str());
            }
        }
    }

    virtual void TearDown() override {

        vcd->flush();
        vcd->close();

        mod->final();

        mod.reset();
        vcd.reset();
        vctx.reset();
    }

    void eval() {
        mod->eval();
        vcd->dump(timeui);
        timeui++;
    }

    
    uint64_t timeui;
    uint64_t clk_cnt;
    std::unique_ptr<VerilatedContext> vctx;
    std::unique_ptr<VerilatedVcdC> vcd;
    std::unique_ptr<T> mod;

};

template <typename T>
class ClockedModTest : public ModTest<T> {

    public:
    void clk() {
        this->timeui += 1;
        this->mod->clk48 = 0;
        this->eval();

        this->timeui += 1;
        this->mod->clk48 = 1;
        this->eval();

        this->clk_cnt += 1;
    }

    void reset() {
        this->mod->reset = 1;

        clk();
        clk();
        clk();

        this->mod->reset = 0;
    }

};

struct USBCaptureInput {
    double time;
    int dn, dp;
};

template <typename T>
class UsbModTest : public ClockedModTest<T> {

    public:
    void bus_reset() {
        this->mod->dn = 0;
        this->mod->dp = 0;
        for (int i = 0; i < (360000-1); i++) {
            this->clk();
        }

    }

    template <typename InputIterator>
    InputIterator step_capture(InputIterator cap_iter) {
        const double now = this->clk_cnt * (1. / (48.*1000.*1000.));

        this->clk();
        if (now > cap_iter->time) {
            this->mod->dn = cap_iter->dn;
            this->mod->dp = cap_iter->dp;
            cap_iter++;
        }
        return cap_iter;
    }
};

std::vector<USBCaptureInput> load_usb_capture(std::string capture_fname);
std::vector<std::vector<uint8_t>> load_usb_decoder_output(std::string decoder_fname);

