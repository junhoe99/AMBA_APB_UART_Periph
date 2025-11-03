# 🔧 AMBA APB UART Peripheral with RISC-V Integration

## 🔍 Project Overview

> 이 프로젝트는 **AMBA APB 프로토콜 기반 UART 주변장치와 RISC-V CPU 통합 시스템**입니다. RISC-V RV32I 프로세서가 APB 버스를 통해 GPIO, UART 등의 주변장치를 제어하는 완전한 SoC 설계를 구현합니다.

## 🏗️ System Architecture

### **High-Level Block Diagram**
```
<img width="8684" height="6576" alt="image" src="https://github.com/user-attachments/assets/996c5946-ed40-40d0-a53c-e7ee9aa03524" />
```

### **Project Structure**
```
📁AMBA_APB_UART_Periph/
├── 📂sources_1/
│   ├── 📂imports/sources_1/
│   │   ├── 📂imports/new/           # RISC-V CPU Core
│   │   │   ├── MCU.sv              # 🎯 Top-level MCU module
│   │   │   ├── CPU_RV32I.sv        # RISC-V RV32I processor
│   │   │   ├── ControlUnit.sv      # CPU control unit
│   │   │   ├── DataPath.sv         # CPU datapath
│   │   │   ├── ROM.sv              # Instruction memory
│   │   │   ├── RAM.sv              # Data memory (APB slave)
│   │   │   ├── defines.sv          # ISA definitions
│   │   │   └── code.mem            # Program binary
│   │   │
│   │   └── 📂new/                  # APB Infrastructure
│   │       ├── APB_Master.sv       # 🚌 APB bus controller
│   │       ├── GPIO.sv             # Bidirectional I/O peripheral
│   │       ├── GPO.sv              # Output-only peripheral
│   │       ├── GPI.sv              # Input-only peripheral
│   │       └── code_org.mem        # Original program
│   │
│   └── 📂new/                      # UART Components
│       ├── uart_fifo_loopback.sv   # 📡 UART peripheral (APB slave)
│       ├── uart.sv                 # Core UART module
│       └── code_sim.mem            # Simulation program
│
├── 📂sim_1/new/                    # Testbenches
│   ├── tb_uart_periph_final.sv     # 🧪 Advanced OOP testbench
│   └── tb_UART_APB_Simple.sv       # Simple UART test
│
└── 📂constrs_1/new/
    └── xdc.xdc                      # 🎛️ FPGA constraints (Basys3)
```

## 🎯 Key Features

### 🏛️ System Integration
- **RISC-V RV32I Core**: 32-bit 프로세서 with full ISA support
- **AMBA APB Protocol**: Industry-standard bus interface
- **Memory-Mapped I/O**: 0x1000_xxxx address space
- **Harvard Architecture**: Separate instruction/data memory

### 🚌 APB Bus Infrastructure
- **APB Master Controller**: State machine-based (IDLE/SETUP/ACCESS)
- **5 APB Slaves**: RAM, GPO, GPI, GPIO, UART
- **Address Decoder**: Automatic peripheral selection
- **Multiplexer**: Read data routing from slaves
- **Full APB Compliance**: PSEL, PENABLE, PREADY, PADDR, PWDATA, PRDATA

### 📡 UART Peripheral Features
- **Memory-Mapped Registers**:
  - `0x00`: Control Register (Enable)
  - `0x04`: Status Register (TX/RX Busy, RX Done)
  - `0x08`: TX Data Register (Write to transmit)
  - `0x0C`: RX Data Register (Read received data)
- **FIFO Support**: TX/RX buffering
- **Loopback Mode**: Internal testing capability
- **Baud Rate**: 9600 bps (configurable)
- **CPU Control**: Full software control via APB

### 🔌 GPIO Peripherals
#### **GPIO (Bidirectional)**
- **Registers**: Control (CR), Output Data (ODR), Input Data (IDR)
- **8-bit width**: Configurable direction per pin
- **Tristate Logic**: Dynamic I/O switching

#### **GPO (Output Only)**
- **Registers**: Control (CR), Output Data (ODR)
- **Dedicated Output**: LED control, etc.

#### **GPI (Input Only)**
- **Registers**: Control (CR), Input Data (IDR)
- **Dedicated Input**: Switch/button reading

## 🗺️ Memory Map

| **Address Range** | **Peripheral** | **Size** | **Description** |
|-------------------|----------------|----------|-----------------|
| `0x1000_0xxx` | RAM | 4KB | Data memory (APB accessible) |
| `0x1000_1xxx` | GPO | 4KB | General Purpose Output |
| `0x1000_2xxx` | GPI | 4KB | General Purpose Input |
| `0x1000_3xxx` | GPIO | 4KB | Bidirectional GPIO |
| `0x1000_4xxx` | UART | 4KB | Serial communication |

### **UART Register Map**
| **Offset** | **Register** | **Access** | **Description** |
|------------|--------------|------------|-----------------|
| `0x00` | CTRL | R/W | bit[0]: UART Enable |
| `0x04` | STATUS | RO | bit[0]: TX Busy, bit[1]: RX Busy, bit[2]: RX Done |
| `0x08` | TX_DATA | R/W | TX data buffer (write triggers transmission) |
| `0x0C` | RX_DATA | RO | RX data buffer |

### **GPIO Register Map**
| **Offset** | **Register** | **Access** | **Description** |
|------------|--------------|------------|-----------------|
| `0x00` | CR | R/W | Control Register (direction: 1=output, 0=input) |
| `0x04` | ODR | R/W | Output Data Register |
| `0x08` | IDR | RO | Input Data Register |

## 🔧 Configuration

### ⚙️ System Parameters
- **⏰ Clock Frequency**: 100MHz
- **📊 Data Width**: 32-bit APB bus
- **💾 Address Width**: 32-bit
- **🎯 Reset Type**: Synchronous reset (active high)

### 🔌 APB Configuration
- **Protocol**: AMBA APB (ARM IHI 0024C)
- **Address Decode**: Base address + 12-bit offset
- **Wait States**: Slave-controlled via PREADY
- **Error Handling**: Basic ready signal timeout

### 📡 UART Configuration
- **Baud Rate**: 9600 bps (100MHz clock)
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None
- **Flow Control**: None

## 🧪 Testing & Verification

### 📋 Verification Methodology
- **Class-Based Testbench**: OOP verification environment
- **Constraint Randomization**: SystemVerilog constraints
- **Transaction-Level Modeling**: Driver/Monitor/Scoreboard architecture
- **Coverage-Driven**: Functional coverage tracking

### 🏗️ Testbench Architecture (`tb_uart_periph_final.sv`)
```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  Generator   │──────▶│   Driver     │──────▶│     DUT      │
│ (Constraints)│       │ (APB Master) │       │ (UART_Periph)│
└──────────────┘       └──────────────┘       └──────┬───────┘
                                                      │
┌──────────────┐       ┌──────────────┐              │
│  Scoreboard  │◀──────│   Monitor    │◀─────────────┘
│ (Checker)    │       │ (Observer)   │
└──────────────┘       └──────────────┘
```

### 🔍 Test Scenarios
1. **APB Basic Operations**: Read/Write transactions
2. **UART TX Operations**: Data transmission
3. **UART RX Operations**: Data reception
4. **LED Control**: GPIO output control
5. **Concurrent Operations**: Simultaneous APB/UART
6. **Error Conditions**: Protocol violations

### 📊 Test Coverage
- **Transaction Types**: Write, Read, Loopback
- **Data Patterns**: Control, Printable, Extended, Commands
- **Register Access**: All UART registers
- **Error Injection**: Invalid addresses, timing violations

## 🚀 Getting Started

### Prerequisites
- **Xilinx Vivado**: 2019.2 or later
- **Target FPGA**: Basys3 (Artix-7)
- **Simulator**: Vivado Simulator or ModelSim

### Simulation
```tcl
# Launch Vivado
# Set tb_uart_periph_final.sv as top module
# Run behavioral simulation
run -all
```

### Synthesis & Implementation
```tcl
# Open project in Vivado
# Run Synthesis
# Run Implementation
# Generate Bitstream
# Program Device
```

## 📈 Performance Specifications

- **⚡ System Clock**: 100MHz
- **🚌 APB Throughput**: 1 transaction per 3 clock cycles (minimum)
- **📡 UART Data Rate**: 9600 baud (960 bytes/sec)
- **🎯 CPU Performance**: 1 IPC (Instructions Per Cycle) - single cycle
- **💾 Memory Latency**: 1 cycle (RAM/ROM)
- **🔄 APB Latency**: 2 cycles minimum (SETUP + ACCESS)

## 🎛️ Hardware Support

### Basys3 FPGA Pin Mapping
- **Clock**: 100MHz system clock (W5)
- **Reset**: Button (U18)
- **GPIO**: 
  - GPO: LEDs (U16-E19)
  - GPI: Switches (V17-R2)
  - GPIO: JB PMOD (A14-B16)
- **UART**:
  - TX: JA1 (J1)
  - RX: JA2 (L2)

## 🔧 Design Highlights

### 💡 Key Design Decisions

1. **Memory-Mapped I/O Architecture**
   - CPU와 주변장치 간 표준화된 인터페이스
   - Software-friendly register access
   - 확장 가능한 주소 공간

2. **APB Protocol Selection**
   - 저전력 주변장치에 최적화
   - 간단한 프로토콜로 검증 용이
   - Industry-standard compliance

3. **Modular Peripheral Design**
   - 각 주변장치별 특화된 레지스터 맵
   - 재사용 가능한 APB slave interface
   - 독립적인 기능 검증

4. **Class-Based Verification**
   - 객체지향 테스트벤치 구조
   - Constraint randomization
   - Self-checking scoreboard

## 🚨 Known Limitations

### ⚠️ Current Constraints
- **No Pipeline**: CPU는 single-cycle 구현
- **No Cache**: Direct memory access only
- **No DMA**: CPU-based data transfer only
- **Limited FIFO**: 4-deep TX/RX buffers
- **No Interrupts**: Polling-based I/O

### 🔮 Future Enhancements
- **Interrupt Controller**: APB interrupt aggregation
- **DMA Controller**: CPU-independent data transfer
- **SPI/I2C Peripherals**: Additional communication protocols
- **Timer/PWM**: Time-based operations
- **Pipeline CPU**: 5-stage RISC-V pipeline

## 📚 References

- **AMBA APB Protocol**: ARM IHI 0024C
- **RISC-V ISA**: RV32I Base Integer Instruction Set
- **SystemVerilog**: IEEE 1800-2017

## 👨‍💻 Author

**Project**: AMBA APB UART Peripheral Integration  
**Repository**: [junhoe99/AMBA_APB_UART_Periph](https://github.com/junhoe99/AMBA_APB_UART_Periph)  
**Status**: ✅ Functional (Simulation Verified)

---

## 📝 License

This project is for educational purposes.

## 🙏 Acknowledgments

- ARM AMBA Specification
- RISC-V Foundation
- Xilinx Vivado Toolchain
