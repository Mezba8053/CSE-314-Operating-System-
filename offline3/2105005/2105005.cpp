#include <pthread.h>
#include <iostream>
#include <semaphore.h>
#include <fstream>
#include <vector>
#include <chrono>
#include <random>
#include <unistd.h>
#include <string>
#define SLEEP_MULTIPLIER 1000
#define Arrival_Time 10000
#define NUM_STATIONS 4
#define NUMBER_OF_STUFF 2

using namespace std;
pthread_mutex_t output_lock;
sem_t station_allocation[NUM_STATIONS];
pthread_mutex_t reader_writer;
sem_t reader_writer_sem;
int reader_count = 0;
int completed_operations = 0;
int total_operations = 0;

auto start_time = std::chrono::high_resolution_clock::now();

int get_random_number(double lamda = 3)
{
    std::random_device rd;
    std::mt19937 generator(rd());
    std::poisson_distribution<int> poissonDist(lamda);
    return poissonDist(generator);
}
class Group;
void write_output(std::string output)
{
    pthread_mutex_lock(&output_lock);
    std::cout << output;
    pthread_mutex_unlock(&output_lock);
}
class Operative
{
public:
    int id;
    int writing_time = 0;
    int type_writing_station = 0;
    int x;
    Group *group;

    int get_time()
    {
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        return duration.count();
    }

    Operative(int id, int x) 
    {
        this->id = id;
        this->x = x;
        type_writing_station = id % 4;
        writing_time = get_random_number();
    }
    int get_station()
    {
        return type_writing_station;
    }
};
class Group
{
    vector<Operative *> operatives;
    sem_t all_group_operatives_sem;
    int completed_count;
    int M;
    int y;
    // int unit_no;

public:
    Group(int size, int y) 
    {   
        this->M = size;
        this->y = y;
        completed_count = 0;
        sem_init(&all_group_operatives_sem, 0, 0);
    }
    ~Group()
    {
        sem_destroy(&all_group_operatives_sem);
    }
    void add_operatives(Operative *op)
    {
        operatives.push_back(op);
    }
    void operative_completed(int operative_id)
    {
        //sem_post(&all_group_operatives_sem);
        completed_count++;
        if (operative_id == operatives[M - 1]->id)
        {
            while (completed_count < M)
            {
                sem_wait(&all_group_operatives_sem);
            }
            write_output("Unit " + to_string(operative_id / M) + " has completed document recreation phase at time " + to_string(operatives[0]->get_time()) + " ms\n");
            write_logbook(operative_id);
        }
        for (int i = 0; i < M; i++)
        {
            sem_post(&all_group_operatives_sem);
        }
    }

    void write_logbook(int leader_id)
    {

        sem_wait(&reader_writer_sem);
        usleep(y * SLEEP_MULTIPLIER);
        completed_operations++;
        write_output("Unit " + to_string(leader_id / M) + " has completed intelligence distribution at time " + to_string(operatives[0]->get_time()) + " ms\n");
        sem_post(&reader_writer_sem);
    }
};

void *operative_thread(void *arg)
{
    Operative *op = (Operative *)arg;
    Group *group = op->group;
    int id = op->id;
    int x = op->x;
    int station = op->get_station();
    usleep(op->writing_time * SLEEP_MULTIPLIER);
    write_output("Operative " + to_string(id) + " arrived at typewriting station at time " + to_string(op->get_time()) + " ms\n");

    // write_output("Operative " + to_string(id) + " arrived at typewriting station " + to_string(station + 1) + " at time " + to_string(op->get_time()) + " ms\n");
    sem_wait(&station_allocation[station]);
    usleep(x * SLEEP_MULTIPLIER);
    write_output("Operative " + to_string(id) + " has completed document recreation at time " + to_string(op->get_time()) + " ms\n");
    sem_post(&station_allocation[station]);
    group->operative_completed(id);

    return NULL;
}
void *intelligence(void *arg)
{
    int staff_id = *(int *)arg;

    while (true)
    {
        usleep(get_random_number(2) * SLEEP_MULTIPLIER);
        pthread_mutex_lock(&reader_writer);
        reader_count++;
        if (reader_count == 1)
        {
            sem_wait(&reader_writer_sem);
        }
        pthread_mutex_unlock(&reader_writer);

        int operations;
        pthread_mutex_lock(&reader_writer);
        operations = completed_operations;
        write_output("Intelligence Staff " + to_string(staff_id) + " began reviewing logbook at time " + to_string(chrono::duration_cast<chrono::milliseconds>(chrono::high_resolution_clock::now() - start_time).count()) + " ms. Operations completed = " + to_string(operations) + "\n");
        pthread_mutex_unlock(&reader_writer);

        usleep(2 * SLEEP_MULTIPLIER);

        pthread_mutex_lock(&reader_writer);
        reader_count--;
        if (reader_count == 0)
        {
            sem_post(&reader_writer_sem);
        }
        if (completed_operations >= total_operations)
        {
            pthread_mutex_unlock(&reader_writer);
            break;
        }
        pthread_mutex_unlock(&reader_writer);
    }
    return NULL;
}

void initialize()
{
    pthread_mutex_init(&output_lock, NULL);
    pthread_mutex_init(&reader_writer, NULL);
    sem_init(&reader_writer_sem, 0, 1);
    start_time = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < NUM_STATIONS; i++)
    {
        sem_init(&station_allocation[i], 0, 1);
    }
}

int main()
{
    ifstream input_file("input.txt");
    if (!input_file.is_open())
    {
        cerr << "Error opening input file." << endl;
        return 1;
    }
    int N, M, x, y;
    input_file >> N >> M;
    input_file >> x >> y;
    pthread_t threads[N];
    initialize();
    vector<Operative *> operatives(N);
    vector<Group *> groups(N / M);
    vector<int> staff_ids(NUMBER_OF_STUFF);
    pthread_t intelligence_threads[NUMBER_OF_STUFF];
    total_operations = N / M;
    for (int i = 0; i < N; i++)
    {
        operatives[i] = new Operative(i + 1, x);
    }
    for (int i = 0; i < N / M; i++)
    {
        groups[i] = new Group(M, y);
        for (int j = 0; j < M; j++)
        {
            operatives[i * M + j]->group = groups[i];
            groups[i]->add_operatives(operatives[i * M + j]);
        }
    }
    for (int i = 0; i < N; i++)
    {
        pthread_create(&threads[i], NULL, operative_thread, (void *)operatives[i]);
    }
    for (int i = 0; i < NUMBER_OF_STUFF; i++)
    {
        staff_ids[i] = i + 1;
        pthread_create(&intelligence_threads[i], NULL, intelligence, (void *)&staff_ids[i]);
    }

    for (int i = 0; i < N; i++)
    {
        pthread_join(threads[i], NULL);
    }
    for (int i = 0; i < NUMBER_OF_STUFF; i++)
    {
        pthread_join(intelligence_threads[i], NULL);
    }
    for (Operative *op : operatives)
    {
        delete op;
    }
    for (Group *g : groups)
    {
        delete g;
    }
    pthread_mutex_destroy(&output_lock);
    for (int i = 0; i < NUM_STATIONS; i++)
    {
        sem_destroy(&station_allocation[i]);
    }
    pthread_mutex_destroy(&reader_writer);
    sem_destroy(&reader_writer_sem);
}
